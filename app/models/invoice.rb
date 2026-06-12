class Invoice < ApplicationRecord
  ACCOUNTS_RECEIVABLE_CODE = "106"
  SALES_CODE = "401"
  OUTPUT_TAX_CODE = "210"

  belongs_to :voucher, optional: true

  before_validation :apply_defaults
  before_validation :calculate_totals

  validates :invoice_number, :issuer, :client_name, :invoice_date, :due_date, :title, :items_json, presence: true
  validates :invoice_number, uniqueness: true
  validates :subtotal, :tax, :total, numericality: { greater_than_or_equal_to: 0 }
  validate :items_must_be_valid
  validate :due_date_not_before_invoice_date
  validate :voucher_accounts_must_exist

  def items
    parsed = JSON.parse(items_json.presence || "[]")
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end

  def invoice_payload
    {
      invoice_number: invoice_number,
      issuer: issuer,
      client_name: client_name,
      invoice_date: invoice_date&.iso8601,
      due_date: due_date&.iso8601,
      title: title,
      items: normalized_items,
      subtotal: subtotal.to_i,
      tax: tax.to_i,
      total: total.to_i,
      note: note.to_s
    }
  end

  def save_with_voucher!
    transaction do
      save!
      ensure_voucher!
    end
  end

  def update_with_voucher!(attributes)
    transaction do
      assign_attributes(attributes)
      save!
      ensure_voucher!
    end
  end

  def ensure_voucher!
    transaction do
      record = voucher || build_voucher(recorded_on: invoice_date)
      record.description = voucher_description
      record.voucher_lines.destroy_all if record.persisted?
      build_voucher_lines(record)
      record.save!
      update!(voucher: record) if voucher_id != record.id
      record
    end
  end

  def mark_issued!(path)
    update!(pdf_path: path.to_s, issued_at: Time.current)
  end

  private

  def apply_defaults
    self.invoice_date ||= Date.current
    self.due_date ||= invoice_date&.+(1.month)
    self.title = "請求書" if title.blank?
    self.items_json = default_items_json if items_json.blank?
    self.invoice_number = default_number if invoice_number.blank?
  end

  def default_number
    date = invoice_date || Date.current
    prefix = date.strftime("%Y-%m")
    last = Invoice.where("invoice_number LIKE ?", "#{prefix}-%").order(:invoice_number).last
    next_seq = last&.invoice_number.to_s.split("-").last.to_i + 1
    format("%<prefix>s-%<seq>03d", prefix: prefix, seq: [ next_seq, 1 ].max)
  end

  def default_items_json
    JSON.pretty_generate([
      { description: "", detail: "", quantity: 1, unit_price: 0, tax_rate: 0.1 }
    ])
  end

  def calculate_totals
    self.subtotal = normalized_items.sum { |item| item[:amount].to_d }
    self.tax = normalized_items.sum { |item| item[:tax].to_d }
    self.total = subtotal.to_d + tax.to_d
  end

  def normalized_items
    items.map do |item|
      row = item.is_a?(Hash) ? item : {}
      description = row["description"].presence || row[:description].to_s
      detail = row["detail"].presence || row[:detail].to_s
      quantity = (row["quantity"] || row[:quantity] || 1).to_d
      unit_price = (row["unit_price"] || row[:unit_price] || row["price"] || row[:price] || 0).to_d
      tax_rate = (row["tax_rate"] || row[:tax_rate] || 0).to_d
      amount = quantity * unit_price
      {
        description: description,
        detail: detail,
        quantity: quantity,
        unit_price: unit_price,
        tax_rate: tax_rate,
        amount: amount,
        tax: (amount * tax_rate).round
      }
    end
  end

  def items_must_be_valid
    parsed = JSON.parse(items_json.presence || "[]")
    errors.add(:items_json, "は配列で入力してください") unless parsed.is_a?(Array)
    errors.add(:items_json, "は1行以上入力してください") if parsed.is_a?(Array) && parsed.empty?
  rescue JSON::ParserError
    errors.add(:items_json, "はJSONとして解釈できません")
  end

  def due_date_not_before_invoice_date
    return if due_date.blank? || invoice_date.blank?
    return if due_date >= invoice_date

    errors.add(:due_date, "は請求日以降にしてください")
  end

  def voucher_accounts_must_exist
    required_codes = [ ACCOUNTS_RECEIVABLE_CODE, SALES_CODE ]
    required_codes << OUTPUT_TAX_CODE if tax.to_d.positive?
    missing_codes = required_codes.reject { |code| Account.exists?(code: code) }
    return if missing_codes.empty?

    errors.add(:base, "請求書用の勘定科目がありません: #{missing_codes.join(', ')}")
  end

  def voucher_description
    [ invoice_number, title, client_name ].compact_blank.join(" ")
  end

  def build_voucher_lines(record)
    record.voucher_lines.build(account_code: ACCOUNTS_RECEIVABLE_CODE, debit_amount: total, credit_amount: 0, note: invoice_number)
    record.voucher_lines.build(account_code: SALES_CODE, debit_amount: 0, credit_amount: subtotal, note: invoice_number)
    return unless tax.to_d.positive?

    record.voucher_lines.build(account_code: OUTPUT_TAX_CODE, debit_amount: 0, credit_amount: tax, note: invoice_number)
  end
end
