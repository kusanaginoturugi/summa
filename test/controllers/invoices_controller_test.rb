require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    [
      [ "106", "売掛金", "asset" ],
      [ "401", "売上高", "revenue" ],
      [ "210", "仮受消費税", "liability" ]
    ].each do |code, name, category|
      Account.find_or_create_by!(code: code) do |account|
        account.name = name
        account.category = category
      end
    end
  end

  test "shows invoice list" do
    get invoices_path

    assert_response :success
    assert_select "h1", "請求書一覧"
    assert_select "a", "請求書作成"
  end

  test "creates invoice and sales voucher" do
    assert_difference([ "Invoice.count", "Voucher.count" ], 1) do
      post invoices_path, params: {
        invoice: {
          issuer: "株式会社発行元",
          client_name: "株式会社テスト",
          invoice_date: "2026-06-11",
          due_date: "2026-07-11",
          title: "開発費",
          items_json: JSON.generate([
            { description: "実装", quantity: 1, unit_price: 50_000, tax_rate: 0.1 }
          ])
        }
      }
    end

    assert_redirected_to invoice_path(Invoice.last)
  end
end
