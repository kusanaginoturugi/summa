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
    assert_select "a[href='#{invoice_path(invoice)}']", false
    assert_select "a[href='#{edit_invoice_path(invoice)}']", "編集"
    assert_select "a[href='#{pdf_invoice_path(invoice)}']", "PDF"
    assert_select "form[action='#{generate_pdf_invoice_path(invoice)}']", false
  end

  test "downloads generated invoice pdf" do
    output_path = Rails.root.join("tmp", "controller-test-invoice.pdf")
    File.write(output_path, "%PDF-1.4\n")
    invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 11),
      due_date: Date.new(2026, 7, 11),
      title: "開発費",
      items_json: JSON.generate([
        { description: "実装", quantity: 1, unit_price: 50_000, tax_rate: 0.1 }
      ]),
      pdf_path: output_path.to_s
    )

    get pdf_invoice_path(invoice)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match %(filename="#{invoice.invoice_number}.pdf"), response.headers["Content-Disposition"]
  ensure
    FileUtils.rm_f(output_path) if output_path
  end

  test "regenerates invoice pdf and downloads it" do
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
    fake_cli = Rails.root.join("tmp", "fake-invoice-cli")
    File.write(fake_cli, <<~SH)
      #!/bin/sh
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --output)
            shift
            output="$1"
            ;;
        esac
        shift
      done
      printf '%s\\n' '%PDF-1.4' > "$output"
    SH
    File.chmod(0o755, fake_cli)
    original_cli = ENV["INVOICE_CLI"]

    ENV["INVOICE_CLI"] = fake_cli.to_s
    post generate_pdf_invoice_path(invoice)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match %(filename="#{invoice.invoice_number}.pdf"), response.headers["Content-Disposition"]
    assert File.file?(invoice.reload.pdf_path)
  ensure
    ENV["INVOICE_CLI"] = original_cli
    FileUtils.rm_f(fake_cli) if fake_cli
    FileUtils.rm_f(invoice&.reload&.pdf_path) if invoice&.pdf_path.present?
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

  test "prefills note from previous month invoice" do
    Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.current.prev_month.change(day: 10),
      due_date: Date.current.prev_month.change(day: 28),
      title: "前月分",
      items_json: JSON.generate([
        { description: "実装", quantity: 1, unit_price: 10_000, tax_rate: 0.1 }
      ]),
      note: "振込先\n山梨中央銀行"
    )

    get new_invoice_path

    assert_response :success
    assert_select "textarea[name='invoice[note]']", "振込先\n山梨中央銀行"
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
    assert_select "textarea[name='invoice[note]']"
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
