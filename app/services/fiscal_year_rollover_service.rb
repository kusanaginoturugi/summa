class FiscalYearRolloverService
  class Error < StandardError; end

  Row = Struct.new(:account_code, :account_name, :category, :balance, keyword_init: true)
  Preview = Struct.new(
    :rows,
    :debit_total,
    :credit_total,
    :difference,
    :from_year,
    :to_year,
    :closing_date,
    :opening_date,
    :description,
    keyword_init: true
  )

  CARRY_FORWARD_CATEGORIES = %w[asset liability equity].freeze

  attr_reader :from_year, :to_year, :balancing_account_code

  def initialize(from_year:, to_year:, balancing_account_code: nil)
    @from_year = from_year.to_i
    @to_year = to_year.to_i
    @balancing_account_code = balancing_account_code.to_s.strip.presence
  end

  def preview
    @preview ||= build_preview
  end

  def execute!
    validate_years!
    raise Error, "この年度繰越はすでに実行されています。" if opening_voucher_exists?

    data = preview
    raise Error, "繰越対象の残高がありません。" if data.rows.blank?

    balancing_account = find_balancing_account_if_needed!(data.difference)

    voucher = nil
    Voucher.transaction do
      voucher = Voucher.new(
        recorded_on: data.opening_date,
        description: data.description
      )

      data.rows.each do |row|
        amount = row.balance.abs
        next if amount.zero?

        if row.balance.positive?
          build_line(voucher, row.account_code, debit: amount, credit: 0)
        else
          build_line(voucher, row.account_code, debit: 0, credit: amount)
        end
      end

      if data.difference.nonzero?
        if data.difference.positive?
          build_line(voucher, balancing_account.code, debit: 0, credit: data.difference.abs, note: "繰越差額調整")
        else
          build_line(voucher, balancing_account.code, debit: data.difference.abs, credit: 0, note: "繰越差額調整")
        end
      end

      voucher.save!
    end

    voucher
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.record.errors.full_messages.join(" / ")
  end

  private

  def build_preview
    validate_years!
    rows = grouped_balances.map do |account_code, account_name, category, balance|
      Row.new(
        account_code: account_code,
        account_name: account_name,
        category: category,
        balance: balance.to_d
      )
    end
    rows = rows.reject { |row| row.balance.zero? }
               .sort_by { |row| row.account_code.to_s }

    debit_total = rows.sum { |row| row.balance.positive? ? row.balance : 0.to_d }
    credit_total = rows.sum { |row| row.balance.negative? ? row.balance.abs : 0.to_d }

    Preview.new(
      rows: rows,
      debit_total: debit_total,
      credit_total: credit_total,
      difference: debit_total - credit_total,
      from_year: from_year,
      to_year: to_year,
      closing_date: closing_date,
      opening_date: opening_date,
      description: opening_description
    )
  end

  def grouped_balances
    VoucherLine.joins(:voucher, :account_master)
               .where(accounts: { category: CARRY_FORWARD_CATEGORIES })
               .where("vouchers.recorded_on <= ?", closing_date)
               .group("voucher_lines.account_code", "accounts.name", "accounts.category")
               .pluck(
                 "voucher_lines.account_code",
                 "accounts.name",
                 "accounts.category",
                 Arel.sql("SUM(voucher_lines.debit_amount - voucher_lines.credit_amount)")
               )
  end

  def build_line(voucher, account_code, debit:, credit:, note: "期首残高繰越")
    line = voucher.voucher_lines.build(
      account_code: account_code,
      debit_amount: debit,
      credit_amount: credit,
      note: note
    )
    line.allow_locked_account = true
    line
  end

  def find_balancing_account_if_needed!(difference)
    return nil if difference.zero?
    raise Error, "貸借差額があります。差額調整科目を指定してください。" if balancing_account_code.blank?

    account = Account.find_by(code: balancing_account_code)
    raise Error, "差額調整科目コード #{balancing_account_code} が存在しません。" if account.nil?

    account
  end

  def validate_years!
    raise Error, "開始年度を入力してください。" if from_year <= 0
    raise Error, "終了年度を入力してください。" if to_year <= 0
    raise Error, "終了年度は開始年度の翌年を指定してください。" unless to_year == from_year + 1
  end

  def opening_voucher_exists?
    Voucher.where(recorded_on: opening_date)
           .where("description LIKE ?", "#{opening_marker}%")
           .exists?
  end

  def opening_marker
    "[期首残高繰越 #{from_year}->#{to_year}]"
  end

  def opening_description
    "#{opening_marker} 前年度残高を開始残高へ"
  end

  def closing_date
    Date.new(from_year, 12, 31)
  end

  def opening_date
    Date.new(to_year, 1, 1)
  end
end
