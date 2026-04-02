require "csv"

# Prefer NKF for encoding detection if available
begin
  require "nkf"
  HAS_NKF = true
rescue LoadError
  HAS_NKF = false
end

class BankCsvImportForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :file
  attribute :bank_account_code, :string
  attribute :deposit_counter_code, :string
  attribute :withdrawal_counter_code, :string
  attribute :date_column, :string, default: "日付"
  attribute :description_column, :string, default: "摘要"
  attribute :deposit_column, :string, default: "入金額"
  attribute :withdrawal_column, :string, default: "出金額"
  attribute :has_header, :boolean, default: true
  attribute :rows, :string
  attribute :setting_id, :integer
  attribute :setting_name, :string
  attribute :save_setting, :boolean, default: false

  attr_reader :created_count, :skipped_rows, :parsed_rows

  FALLBACK_COUNTER_CODE = "999"

  validates :file, presence: true, unless: -> { rows.present? }
  validates :bank_account_code, :deposit_counter_code, :withdrawal_counter_code, presence: true
  validate :accounts_exist

  def save
    return false unless valid?

    @created_count = 0
    @skipped_rows = []
    @parsed_rows = build_rows
    errors.add(:base, I18n.t("bank_imports.errors.no_rows")) if @parsed_rows.empty?
    return false unless errors.empty?

    ensure_fallback_account! if fallback_code_used?

    ActiveRecord::Base.transaction do
      persist_setting if save_setting?
      @parsed_rows.each do |row|
        create_voucher(row[:date], row[:description], row[:deposit].to_d, :deposit, row[:counter_code]) if row[:deposit].to_d.positive?
        create_voucher(row[:date], row[:description], row[:withdrawal].to_d, :withdrawal, row[:counter_code]) if row[:withdrawal].to_d.positive?
      end
    end

    errors.add(:base, I18n.t("bank_imports.errors.no_rows")) if created_count.zero?
    log_skipped_rows if skipped_rows.present?
    errors.empty?
  rescue StandardError => e
    errors.add(:base, e.message)
    false
  end

  def rows_json
    (parsed_rows || []).to_json
  end

  private

  def accounts_exist
    %i[bank_account_code deposit_counter_code withdrawal_counter_code].each do |key|
      code = public_send(key)
      next if code.blank?

      account = Account.find_by(code: code)
      if account.nil?
        errors.add(key, I18n.t("bank_imports.errors.account_missing", code: code))
      elsif account.is_lock?
        errors.add(key, "はロックされているため使用できません")
      end
    end
  end

  def detect_encoding(io)
    io.rewind
    sample = (io.read(4000) || "").dup
    sample.force_encoding(Encoding::ASCII_8BIT)
    return "UTF-8" if sample.start_with?("\xEF\xBB\xBF".b)

    if HAS_NKF
      guessed = NKF.guess(sample)
      return "CP932" if [Encoding::Shift_JIS, Encoding::Windows_31J, Encoding::CP932].include?(guessed)
      return "UTF-8" if guessed == Encoding::UTF_8
    end

    utf8_sample = sample.dup.force_encoding("UTF-8")
    return "UTF-8" if utf8_sample.valid_encoding?

    "CP932"
  ensure
    io.rewind
  end

  def save_setting?
    ActiveModel::Type::Boolean.new.cast(save_setting) || setting_name.present?
  end

  def has_header?
    ActiveModel::Type::Boolean.new.cast(has_header)
  end

  def persist_setting
    setting = if setting_id.present?
                BankImportSetting.find_by(id: setting_id)
              end
    setting ||= BankImportSetting.find_or_initialize_by(name: setting_name.presence || I18n.t("bank_imports.shared.default_setting_name"))

    attrs = {
      bank_account_code: bank_account_code,
      deposit_counter_code: deposit_counter_code,
      withdrawal_counter_code: withdrawal_counter_code,
      date_column: date_column,
      description_column: description_column,
      deposit_column: deposit_column,
      withdrawal_column: withdrawal_column
    }
    attrs[:has_header] = has_header if column_exists?(:bank_import_settings, :has_header)

    setting.assign_attributes(attrs)
    setting.save!
  end

  def column_exists?(table, column)
    ActiveRecord::Base.connection.column_exists?(table, column)
  end

  def cell(row, key)
    # key: column name or 1-based index (String/Integer)
    raw =
      if has_header?
        numeric?(key) ? row[numeric_index(key)] : row[key]
      else
        row[numeric_index(key)]
      end
    normalize_string(raw)
  end

  def numeric?(value)
    value.to_s.match?(/\A\d+\z/)
  end

  def description_text(row)
    cols = split_columns(description_column)
    parts = cols.map { |col| cell(row, col).strip }.reject(&:blank?)
    parts.join(" / ")
  end

  def split_columns(value)
    value.to_s.split(/[,\s]+/).reject(&:blank?)
  end

  def numeric_index(value)
    value.to_i - 1
  end

  def skip_row(line_no, reason)
    @skipped_rows << { line: line_no, reason: normalize_string(reason) }
  end

  def log_skipped_rows
    msgs = skipped_rows.map { |r| "line #{r[:line]}: #{r[:reason]}" }.join(", ")
    Rails.logger.info("[BankImport] skipped rows: #{msgs}")
  end

  # Parse only, do not persist vouchers
  def parse_only
    @created_count = 0
    @skipped_rows = []
    @parsed_rows = build_rows
    errors.add(:base, I18n.t("bank_imports.errors.no_rows")) if @parsed_rows.empty?
    errors.empty?
  rescue StandardError => e
    errors.add(:base, e.message)
    false
  end

  def create_voucher(recorded_on, description, amount, direction, counter_code)
    voucher = Voucher.new(recorded_on: recorded_on, description: description)

    bank_code = bank_account_code.to_s.strip
    deposit_code = deposit_counter_code.to_s.strip
    withdrawal_code = withdrawal_counter_code.to_s.strip
    counter_code = counter_code.to_s.strip
    counter_code = nil if counter_code.blank?

    if direction == :deposit
      voucher.voucher_lines.build(account_code: bank_code, debit_amount: amount, credit_amount: 0)
      voucher.voucher_lines.build(account_code: counter_code || deposit_code, debit_amount: 0, credit_amount: amount)
    else
      voucher.voucher_lines.build(account_code: counter_code || withdrawal_code, debit_amount: amount, credit_amount: 0)
      voucher.voucher_lines.build(account_code: bank_code, debit_amount: 0, credit_amount: amount)
    end

    voucher.save!
    @created_count += 1
  end

  def parse_date(value)
    str = normalize_string(value).strip
    return nil if str.blank?

    if str.match?(/\A\d{4}年\d{1,2}月\d{1,2}日\z/)
      return Date.strptime(str, "%Y年%m月%d日")
    elsif str.match?(/\A\d{1,2}月\d{1,2}日\z/)
      year = Date.current.year
      return Date.strptime("#{year}年#{str}", "%Y年%m月%d日")
    elsif str.match?(/\A\d{4}\/\d{1,2}\/\d{1,2}\z/)
      return Date.strptime(str, "%Y/%m/%d")
    end

    Date.parse(str)
  rescue ArgumentError
    nil
  end

  def decimal(value)
    str = normalize_string(value)
    # Normalize minus variants used in Japanese bank CSVs.
    str = str.tr("−‐‑‒–—―ーｰ－", "-")
    negative_format = str.include?("▲") || str.include?("(")
    cleaned = str.tr("¥￥,\\", "").gsub(/[()\s]/, "")
    if cleaned.end_with?("-")
      cleaned = "-#{cleaned[0...-1]}"
    end
    num = BigDecimal(cleaned.presence || "0")
    negative_format && num.positive? ? -num : num
  rescue ArgumentError, TypeError
    0.to_d
  end

  def normalize_amounts(deposit, withdrawal)
    dep = deposit.to_d
    wdr = withdrawal.to_d

    # Some bank CSVs output withdrawals as negative values.
    if wdr.negative?
      dep += wdr.abs
      wdr = 0.to_d
    end

    # Normalize opposite case as well for robustness.
    if dep.negative?
      wdr += dep.abs
      dep = 0.to_d
    end

    [dep, wdr]
  end

  def normalize_string(val)
    str = val.to_s
    return "" if str.empty?
    str = str.dup
    str.force_encoding(Encoding::UTF_8) if str.encoding == Encoding::ASCII_8BIT
    str.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
  end

  def upload_io
    return file.tempfile if file.respond_to?(:tempfile)
    return file.to_io if file.respond_to?(:to_io)
    return file if file.respond_to?(:read)

    raise ArgumentError, "file is required"
  end

  def build_rows
    return JSON.parse(rows).map(&:symbolize_keys) if rows.present?

    io = upload_io
    encoding = detect_encoding(io)
    io.rewind

    raw = io.read
    raw.force_encoding(encoding)
    utf8 = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

    csv = CSV.parse(utf8, headers: has_header?)
    line_no_offset = has_header? ? 2 : 1

    parsed = []
    csv.each_with_index do |row, idx|
      line_no = line_no_offset + idx
      begin
        deposit = decimal(cell(row, deposit_column))
        withdrawal = decimal(cell(row, withdrawal_column))
        deposit, withdrawal = normalize_amounts(deposit, withdrawal)
        if deposit.zero? && withdrawal.zero?
          skip_row(line_no, :no_amount)
          next
        end

        date = parse_date(cell(row, date_column))
        if date.nil?
          skip_row(line_no, :invalid_date)
          next
        end

        description = description_text(row)

        counter_code = rule_account_code(description, deposit: deposit, withdrawal: withdrawal)
        parsed << { date: date, description: description, deposit: deposit, withdrawal: withdrawal, counter_code: counter_code }
      rescue StandardError => e
        skip_row(line_no, e.message)
      end
    end

    parsed
  end

  def rule_account_code(description, deposit:, withdrawal:)
    direction = deposit.to_d.positive? ? "deposit" : "withdrawal"
    rule = ImportRule.match_for(description, direction)
    return rule.account_code if rule
    FALLBACK_COUNTER_CODE
  end

  public :parse_only

  def fallback_code_used?
    return true if [deposit_counter_code, withdrawal_counter_code].map(&:to_s).include?(FALLBACK_COUNTER_CODE)
    @parsed_rows.any? { |row| row[:counter_code].to_s == FALLBACK_COUNTER_CODE }
  end

  def ensure_fallback_account!
    return if Account.exists?(code: FALLBACK_COUNTER_CODE)

    Account.create!(
      code: FALLBACK_COUNTER_CODE,
      name: I18n.t("bank_imports.shared.fallback_account_name", default: "貸借不一致"),
      category: "expense"
    )
  end
end
