class Voucher < ApplicationRecord
  has_many :voucher_lines, dependent: :destroy

  accepts_nested_attributes_for :voucher_lines, allow_destroy: true, reject_if: :blank_line?

  before_validation :apply_defaults
  before_destroy :prevent_destroy_if_locked_account_included

  validates :recorded_on, presence: true
  validates :voucher_number, presence: true
  validate :at_least_one_line
  validate :balanced_entries
  validate :prevent_update_if_locked_account_included, on: :update

  validates :voucher_number, uniqueness: true

  def total_debit
    voucher_lines.sum { |line| line.debit_amount.to_d }
  end

  def total_credit
    voucher_lines.sum { |line| line.credit_amount.to_d }
  end

  def balance_difference
    total_debit - total_credit
  end

  def locked_account_codes
    return [] if id.blank?

    VoucherLine.joins(:account_master)
               .where(voucher_id: id, accounts: { is_lock: true })
               .distinct
               .pluck(:account_code)
  end

  def locked_for_edit?
    locked_account_codes.any?
  end

  private

  def apply_defaults
    self.recorded_on ||= Date.current
    self.voucher_number = default_number if voucher_number.blank?
  end

  def default_number
    date_str = (recorded_on || Date.current).strftime("%Y%m%d")
    last = Voucher.where("voucher_number LIKE ?", "#{date_str}-%").order(:voucher_number).last
    next_seq = last&.voucher_number.to_s.split("-").last.to_i + 1
    format("%<date>s-%<seq>03d", date: date_str, seq: [next_seq, 1].max)
  end

  def blank_line?(attrs)
    attrs.slice(:account, :debit_amount, :credit_amount, :note).values.all?(&:blank?)
  end

  def at_least_one_line
    errors.add(:base, "明細を1行以上入力してください") if voucher_lines.reject(&:marked_for_destruction?).empty?
  end

  def balanced_entries
    return if voucher_lines.empty?
    errors.add(:base, "借方と貸方の合計が一致していません") unless balance_difference.zero?
  end

  def prevent_update_if_locked_account_included
    return unless locked_for_edit?

    errors.add(:base, "ロックされた科目を含む仕訳は変更できません")
  end

  def prevent_destroy_if_locked_account_included
    return unless locked_for_edit?

    errors.add(:base, "ロックされた科目を含む仕訳は変更できません")
    throw(:abort)
  end
end
