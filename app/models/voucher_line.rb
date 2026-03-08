class VoucherLine < ApplicationRecord
  attr_accessor :allow_locked_account
  scope :in_fiscal_year, ->(year) do
    y = year.to_i
    next all unless y.positive?

    joins(:voucher).where(vouchers: { recorded_on: Date.new(y, 1, 1)..Date.new(y, 12, 31) })
  end

  belongs_to :voucher
  belongs_to :account_master, class_name: "Account", primary_key: :code, foreign_key: :account_code, optional: true

  before_validation :normalize_amounts
  before_validation :sync_account_name
  before_destroy :prevent_destroy_when_voucher_locked

  validates :account_code, presence: true
  validates :account, presence: true
  validate :account_exists
  validate :account_not_locked
  validate :amount_present
  validate :prevent_update_when_voucher_locked, on: :update

  private

  def normalize_amounts
    self.debit_amount = (debit_amount.presence || 0).to_d
    self.credit_amount = (credit_amount.presence || 0).to_d
  end

  def sync_account_name
    return if account_code.blank?
    self.account_master = Account.find_by(code: account_code)
    self.account = account_master&.name
  end

  def account_exists
    errors.add(:account_code, "が科目表に存在しません") if account_code.present? && account_master.nil?
  end

  def account_not_locked
    return if account_master.nil?
    return if allow_locked_account
    return unless account_master.is_lock?

    errors.add(:account_code, "はロックされているため使用できません")
  end

  def amount_present
    if debit_amount.to_d.zero? && credit_amount.to_d.zero?
      errors.add(:base, "借方または貸方の金額を入力してください")
    end
  end

  def prevent_update_when_voucher_locked
    return unless voucher_locked_for_edit?

    errors.add(:base, "ロックされた科目を含む仕訳は変更できません")
  end

  def prevent_destroy_when_voucher_locked
    return unless voucher_locked_for_edit?

    errors.add(:base, "ロックされた科目を含む仕訳は変更できません")
    throw(:abort)
  end

  def voucher_locked_for_edit?
    return false if voucher_id.blank?

    VoucherLine.joins(:account_master).where(voucher_id: voucher_id, accounts: { is_lock: true }).exists?
  end
end
