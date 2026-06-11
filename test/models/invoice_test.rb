require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
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

  test "assigns invoice number and calculates totals from items" do
    invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 4),
      due_date: Date.new(2026, 6, 30),
      title: "開発費",
      items_json: JSON.generate([
        { description: "実装", quantity: 2, unit_price: 10_000, tax_rate: 0.1 },
        { description: "調整", quantity: 1, unit_price: 5_000, tax_rate: 0 }
      ])
    )

    assert_equal "2026-06-001", invoice.invoice_number
    assert_equal 25_000, invoice.subtotal.to_i
    assert_equal 2_000, invoice.tax.to_i
    assert_equal 27_000, invoice.total.to_i
  end

  test "creates linked sales voucher" do
    invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 4),
      due_date: Date.new(2026, 6, 30),
      title: "開発費",
      items_json: JSON.generate([
        { description: "実装", quantity: 1, unit_price: 10_000, tax_rate: 0.1 }
      ])
    )

    voucher = invoice.ensure_voucher!

    assert_equal voucher.id, invoice.reload.voucher_id
    assert_equal invoice.invoice_date, voucher.recorded_on
    assert_equal 11_000, voucher.total_debit.to_i
    assert_equal 11_000, voucher.total_credit.to_i
    assert_equal [ "106", "401", "210" ], voucher.voucher_lines.order(:id).pluck(:account_code)
  end

  test "exports invoice payload for invoice cli" do
    invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 4),
      due_date: Date.new(2026, 6, 30),
      title: "開発費",
      items_json: JSON.generate([ { description: "実装", quantity: 1, unit_price: 10_000, tax_rate: 0.1 } ]),
      note: "翌月末払い"
    )

    payload = invoice.invoice_payload

    assert_equal invoice.invoice_number, payload[:invoice_number]
    assert_equal "株式会社発行元", payload[:issuer]
    assert_equal "株式会社テスト", payload[:client_name]
    assert_equal 11_000, payload[:total]
    assert_equal "翌月末払い", payload[:note]
    assert_equal "実装", payload[:items].first[:description]
  end
end
