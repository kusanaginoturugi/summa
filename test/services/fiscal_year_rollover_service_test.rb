require "test_helper"

class FiscalYearRolloverServiceTest < ActiveSupport::TestCase
  setup do
    @cash = create_account!("101", "現金", "asset")
    @equity = create_account!("301", "元入金", "equity")
    @sales = create_account!("401", "売上高", "revenue")

    Voucher.create!(
      recorded_on: Date.new(2025, 12, 31),
      description: "期末残高",
      voucher_lines_attributes: {
        "0" => { account_code: @cash.code, debit_amount: 1000, credit_amount: 0 },
        "1" => { account_code: @equity.code, debit_amount: 0, credit_amount: 1000 }
      }
    )

    Account.update_all(is_lock: true)
  end

  test "unlocks accounts after successful rollover" do
    voucher = FiscalYearRolloverService.new(from_year: 2025, to_year: 2026).execute!

    assert_equal Date.new(2026, 1, 1), voucher.recorded_on
    assert_equal false, @cash.reload.is_lock?
    assert_equal false, @equity.reload.is_lock?
    assert_equal false, @sales.reload.is_lock?
  end

  private

  def create_account!(code, name, category)
    Account.find_or_create_by!(code: code) do |account|
      account.name = name
      account.category = category
    end
  end
end
