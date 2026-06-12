require "open3"

class InvoicePdfGenerator
  class Error < StandardError; end

  def initialize(invoice, command: ENV.fetch("INVOICE_CLI", Rails.root.join("invoice", "invoice").to_s))
    @invoice = invoice
    @command = command
  end

  def generate!(output_path: default_output_path, import_path: default_import_path)
    FileUtils.mkdir_p(File.dirname(import_path))
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(import_path, JSON.pretty_generate(cli_payload))

    stdout, stderr, status = Open3.capture3(@command, "generate", "--import", import_path.to_s, "--output", output_path.to_s)
    raise Error, command_error(stdout, stderr) unless status.success?

    InvoicePdfValidator.validate!(output_path)
    @invoice.mark_issued!(output_path)
  end

  private

  def default_import_path
    Rails.root.join("tmp", "invoices", "#{@invoice.invoice_number}.json")
  end

  def default_output_path
    Rails.root.join("storage", "invoices", "#{@invoice.invoice_number}.pdf")
  end

  def cli_payload
    items = @invoice.invoice_payload[:items]
    subtotal = @invoice.subtotal.to_d

    {
      id: @invoice.invoice_number,
      title: @invoice.title,
      from: @invoice.issuer,
      to: @invoice.client_name,
      date: @invoice.invoice_date.strftime("%Y/%m/%d"),
      due: @invoice.due_date.strftime("%Y/%m/%d"),
      items: items.map { |item| item[:description] },
      details: items.map { |item| item[:detail] },
      quantities: items.map { |item| item[:quantity].to_i },
      rates: items.map { |item| item[:unit_price].to_f },
      tax: subtotal.zero? ? 0 : (@invoice.tax.to_d / subtotal).to_f,
      currency: "JPY",
      note: @invoice.note.to_s
    }
  end

  def command_error(stdout, stderr)
    message = [ stderr.presence, stdout.presence ].compact.join("\n").presence || "invoice CLI failed"
    "PDF生成に失敗しました: #{message}"
  end
end
