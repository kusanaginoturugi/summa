class AccountRegisterLineUpdateForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :line_id, :integer
  attribute :account_code, :string
  attribute :recorded_on, :date
  attribute :description, :string
  attribute :counterpart_code, :string
  attribute :amount, :decimal

  validates :line_id, :account_code, :recorded_on, :counterpart_code, :amount, presence: true
  validate :account_exists
  validate :counterpart_exists
  validate :account_unlocked
  validate :counterpart_unlocked
  validate :amount_not_zero
  validate :line_exists
  validate :line_belongs_to_selected_account
  validate :simple_voucher_only
  validate :voucher_not_locked

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      voucher.update!(
        recorded_on: recorded_on,
        description: description.to_s.strip.presence
      )

      signed_amount = amount.to_d
      if signed_amount.positive?
        register_line.update!(account_code: account_code, debit_amount: signed_amount, credit_amount: 0)
        counterpart_line.update!(account_code: counterpart_code, debit_amount: 0, credit_amount: signed_amount)
      else
        abs_amount = signed_amount.abs
        register_line.update!(account_code: account_code, debit_amount: 0, credit_amount: abs_amount)
        counterpart_line.update!(account_code: counterpart_code, debit_amount: abs_amount, credit_amount: 0)
      end
    end

    ImportRule.record_from_voucher(voucher.reload)
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.join(" / "))
    false
  end

  private

  def register_line
    @register_line ||= VoucherLine.includes(:voucher).find_by(id: line_id)
  end

  def voucher
    register_line&.voucher
  end

  def counterpart_line
    return nil if voucher.nil?
    @counterpart_line ||= voucher.voucher_lines.find { |line| line.id != register_line.id }
  end

  def account_exists
    return if account_code.blank?
    errors.add(:account_code, "が科目表に存在しません") if Account.find_by(code: account_code).nil?
  end

  def counterpart_exists
    return if counterpart_code.blank?
    errors.add(:counterpart_code, "が科目表に存在しません") if Account.find_by(code: counterpart_code).nil?
  end

  def account_unlocked
    return if account_code.blank?
    account = Account.find_by(code: account_code)
    return if account.nil? || !account.is_lock?

    errors.add(:account_code, "はロックされているため使用できません")
  end

  def counterpart_unlocked
    return if counterpart_code.blank?
    account = Account.find_by(code: counterpart_code)
    return if account.nil? || !account.is_lock?

    errors.add(:counterpart_code, "はロックされているため使用できません")
  end

  def amount_not_zero
    errors.add(:amount, "は0以外の値を入力してください") if amount.to_d.zero?
  end

  def line_exists
    errors.add(:line_id, "が不正です") if register_line.nil?
  end

  def line_belongs_to_selected_account
    return if register_line.nil? || account_code.blank?
    return if register_line.account_code == account_code

    errors.add(:base, "選択中の科目と対象仕訳が一致しません")
  end

  def simple_voucher_only
    return if voucher.nil?
    return if voucher.voucher_lines.size == 2 && counterpart_line.present?

    errors.add(:base, "複数明細の伝票は通常の伝票編集画面で修正してください")
  end

  def voucher_not_locked
    return if voucher.nil?
    return unless voucher.locked_for_edit?

    errors.add(:base, "ロックされた科目を含む仕訳は変更できません")
  end
end
