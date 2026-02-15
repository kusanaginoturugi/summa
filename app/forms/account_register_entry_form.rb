class AccountRegisterEntryForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :account_code, :string
  attribute :recorded_on, :date
  attribute :description, :string
  attribute :counterpart_code, :string
  attribute :amount, :decimal

  validates :account_code, :recorded_on, :counterpart_code, :amount, presence: true
  validate :account_exists
  validate :counterpart_exists
  validate :amount_not_zero

  def save
    return false unless valid?

    voucher = Voucher.new(
      recorded_on: recorded_on,
      description: description.to_s.strip.presence
    )

    signed_amount = amount.to_d
    if signed_amount.positive?
      voucher.voucher_lines.build(account_code: account_code, debit_amount: signed_amount, credit_amount: 0)
      voucher.voucher_lines.build(account_code: counterpart_code, debit_amount: 0, credit_amount: signed_amount)
    else
      abs_amount = signed_amount.abs
      voucher.voucher_lines.build(account_code: counterpart_code, debit_amount: abs_amount, credit_amount: 0)
      voucher.voucher_lines.build(account_code: account_code, debit_amount: 0, credit_amount: abs_amount)
    end

    voucher.save!
    ImportRule.record_from_voucher(voucher)
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.join(" / "))
    false
  end

  private

  def account_exists
    return if account_code.blank?
    errors.add(:account_code, "が科目表に存在しません") if Account.find_by(code: account_code).nil?
  end

  def counterpart_exists
    return if counterpart_code.blank?
    errors.add(:counterpart_code, "が科目表に存在しません") if Account.find_by(code: counterpart_code).nil?
  end

  def amount_not_zero
    errors.add(:amount, "は0以外の値を入力してください") if amount.to_d.zero?
  end
end
