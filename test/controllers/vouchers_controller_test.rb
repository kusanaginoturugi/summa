require "test_helper"

class VouchersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bank = create_account!("19991", "テスト銀行", "asset")
    @owner_draw = create_account!("303", "事業主貸", "equity")
  end

  test "redirects to register after deleting voucher from register detail" do
    voucher = Voucher.create!(
      recorded_on: Date.new(2026, 5, 31),
      description: "事業主貸",
      voucher_lines_attributes: {
        "0" => { account_code: @owner_draw.code, debit_amount: 1000, credit_amount: 0 },
        "1" => { account_code: @bank.code, debit_amount: 0, credit_amount: 1000 }
      }
    )

    assert_difference("Voucher.count", -1) do
      delete voucher_path(voucher), params: {
        return_to: "register",
        return_account_code: @bank.code,
        return_description: "事業主",
        return_from_month: "2026-05",
        return_to_month: "2026-05",
        return_anchor: "line-#{voucher.voucher_lines.last.id}"
      }
    end

    assert_redirected_to register_vouchers_path(
      account_code: @bank.code,
      description: "事業主",
      from_month: "2026-05",
      to_month: "2026-05",
      anchor: "line-#{voucher.voucher_lines.last.id}"
    )
  end

  test "filters register rows by month range" do
    create_transfer!(Date.new(2026, 4, 30), "四月", 1000)
    create_transfer!(Date.new(2026, 5, 31), "五月", 2000)

    get register_vouchers_path(account_code: @bank.code, from_month: "2026-05", to_month: "2026-05")

    assert_response :success
    assert_select "td", text: "五月"
    assert_select "td", text: "四月", count: 0
    assert_includes response.body, "-3,000"
    assert_select "select[name='from_month'] option[selected][value='2026-05']", text: "5月"
    assert_select "select[name='to_month'] option[selected][value='2026-05']", text: "5月"
  end

  private

  def create_account!(code, name, category)
    Account.find_or_create_by!(code: code) do |account|
      account.name = name
      account.category = category
    end
  end

  def create_transfer!(recorded_on, description, amount)
    Voucher.create!(
      recorded_on: recorded_on,
      description: description,
      voucher_lines_attributes: {
        "0" => { account_code: @owner_draw.code, debit_amount: amount, credit_amount: 0 },
        "1" => { account_code: @bank.code, debit_amount: 0, credit_amount: amount }
      }
    )
  end
end
