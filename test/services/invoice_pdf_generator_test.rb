require "test_helper"

class InvoicePdfGeneratorTest < ActiveSupport::TestCase
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

    @invoice = Invoice.create!(
      issuer: "株式会社発行元",
      client_name: "株式会社テスト",
      invoice_date: Date.new(2026, 6, 4),
      due_date: Date.new(2026, 6, 30),
      title: "開発費",
      items_json: JSON.generate([ { description: "実装", quantity: 1, unit_price: 10_000, tax_rate: 0.1 } ])
    )
  end

  test "generates pdf through invoice cli and records issued path" do
    fake_cli = Rails.root.join("tmp", "fake-invoice-cli")
    import_path = Rails.root.join("tmp", "test-invoice.json")
    output_path = Rails.root.join("tmp", "test-invoice.pdf")
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

    InvoicePdfGenerator.new(@invoice, command: fake_cli.to_s).generate!(
      import_path: import_path,
      output_path: output_path
    )

    assert_equal output_path.to_s, @invoice.reload.pdf_path
    assert @invoice.issued_at.present?
    payload = JSON.parse(File.read(import_path))
    assert_equal @invoice.invoice_number, payload["id"]
    assert_equal "株式会社発行元", payload["from"]
    assert_equal "株式会社テスト", payload["to"]
    assert_equal [ "実装" ], payload["items"]
    assert_equal 0.1, payload["tax"]
  ensure
    FileUtils.rm_f(fake_cli)
    FileUtils.rm_f(import_path)
    FileUtils.rm_f(output_path)
  end
end
