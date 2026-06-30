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
    invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 11),
      due_date: Date.new(2026, 7, 11),
      title: "開発費",
      items_json: JSON.generate([
        { description: "実装", quantity: 1, unit_price: 50_000, tax_rate: 0.1 }
      ])
    )

    get invoices_path

    assert_response :success
    assert_select "h1", "請求書一覧"
    assert_select "a", "請求書作成"
    assert_select "a[href='#{edit_invoice_path(invoice)}']", "編集"
    assert_select "form[action='#{generate_pdf_invoice_path(invoice)}'] button", "PDF生成"
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
          invoice_items: {
            "0" => {
              description: "実装",
              detail: "管理画面の改修\nPDF出力対応",
              quantity: "1",
              unit_price: "50000",
              tax_rate: "0.1"
            }
          }
        }
      }
    end

    invoice = Invoice.last
    assert_redirected_to invoice_path(invoice)
    assert_equal "管理画面の改修\nPDF出力対応", invoice.invoice_payload[:items].first[:detail]
    assert_equal 55_000, invoice.total.to_i
  end

  test "shows invoice items in edit form" do
    invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 11),
      due_date: Date.new(2026, 7, 11),
      title: "開発費",
      items_json: JSON.generate([
        {
          description: "実装",
          detail: "既存の詳細",
          quantity: 2,
          unit_price: 50_000,
          tax_rate: 0.1
        }
      ])
    )

    get edit_invoice_path(invoice)

    assert_response :success
    assert_select "input[name='invoice[invoice_items][0][description]'][value='実装']"
    assert_select "textarea[name='invoice[invoice_items][0][detail]']", "既存の詳細"
    assert_select "input[name='invoice[invoice_items][0][quantity]'][value='2.0']"
  end

  test "updates invoice items and sales voucher" do
    invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 11),
      due_date: Date.new(2026, 7, 11),
      title: "開発費",
      items_json: JSON.generate([
        { description: "実装", quantity: 1, unit_price: 50_000, tax_rate: 0.1 }
      ])
    )
    invoice.ensure_voucher!

    patch invoice_path(invoice), params: {
      invoice: {
        issuer: invoice.issuer,
        client_name: invoice.client_name,
        invoice_date: invoice.invoice_date,
        due_date: invoice.due_date,
        title: invoice.title,
        invoice_items: {
          "0" => {
            description: "更新後の実装",
            detail: "更新後の詳細",
            quantity: "2",
            unit_price: "30000",
            tax_rate: "0.1"
          }
        }
      }
    }

    assert_redirected_to invoice_path(invoice)
    invoice.reload
    assert_equal "更新後の実装", invoice.invoice_payload[:items].first[:description]
    assert_equal "更新後の詳細", invoice.invoice_payload[:items].first[:detail]
    assert_equal 66_000, invoice.total.to_i
    assert_equal 66_000, invoice.voucher.total_debit.to_i
  end
end
