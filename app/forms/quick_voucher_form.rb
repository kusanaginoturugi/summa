class QuickVoucherForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :recorded_on, :date
  attribute :account_code, :string
  attribute :counter_account_code, :string
  attribute :amount, :decimal
  attribute :direction, :string
  attribute :description, :string

  attr_accessor :account_code_deposit, :counter_account_code_deposit,
                :account_code_withdrawal, :counter_account_code_withdrawal,
                :amount_deposit, :amount_withdrawal,
                :description_deposit, :description_withdrawal

  validates :recorded_on, :account_code, :counter_account_code, :amount, :direction, presence: true
  validates :direction, inclusion: { in: %w[deposit withdrawal] }
  validate :amount_positive
  validate :account_exists
  validate :counter_account_exists
  validate :account_unlocked
  validate :counter_account_unlocked

  def save
    apply_direction_values
    return false unless valid?

    voucher = Voucher.new(recorded_on: recorded_on, description: description.presence)
    amount_value = amount.to_d

    if direction == "deposit"
      voucher.voucher_lines.build(account_code: account_code, debit_amount: amount_value, credit_amount: 0)
      voucher.voucher_lines.build(account_code: counter_account_code, debit_amount: 0, credit_amount: amount_value)
    else
      voucher.voucher_lines.build(account_code: counter_account_code, debit_amount: amount_value, credit_amount: 0)
      voucher.voucher_lines.build(account_code: account_code, debit_amount: 0, credit_amount: amount_value)
    end

    voucher.save!
    ImportRule.record_from_voucher(voucher)
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.join(" / "))
    false
  end

  private

  def apply_direction_values
    if direction == "deposit"
      self.account_code = account_code_deposit if account_code_deposit.present?
      self.counter_account_code = counter_account_code_deposit if counter_account_code_deposit.present?
      self.amount = amount_deposit if amount_deposit.present?
      self.description = description_deposit if description_deposit.present?
    elsif direction == "withdrawal"
      self.account_code = account_code_withdrawal if account_code_withdrawal.present?
      self.counter_account_code = counter_account_code_withdrawal if counter_account_code_withdrawal.present?
      self.amount = amount_withdrawal if amount_withdrawal.present?
      self.description = description_withdrawal if description_withdrawal.present?
    end
  end

  def amount_positive
    errors.add(:amount, "は0より大きい値を入力してください") if amount.to_d <= 0
  end

  def account_exists
    return if account_code.blank?
    errors.add(:account_code, "が科目表に存在しません") if Account.find_by(code: account_code).nil?
  end

  def counter_account_exists
    return if counter_account_code.blank?
    errors.add(:counter_account_code, "が科目表に存在しません") if Account.find_by(code: counter_account_code).nil?
  end

  def account_unlocked
    return if account_code.blank?
    account = Account.find_by(code: account_code)
    return if account.nil? || !account.is_lock?

    errors.add(:account_code, "はロックされているため使用できません")
  end

  def counter_account_unlocked
    return if counter_account_code.blank?
    account = Account.find_by(code: counter_account_code)
    return if account.nil? || !account.is_lock?

    errors.add(:counter_account_code, "はロックされているため使用できません")
  end
end
