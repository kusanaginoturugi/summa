require "json"
require "open3"
require "tempfile"

class EstimatePdfService
  class GenerationError < StandardError; end

  def initialize(estimate)
    @estimate = estimate
  end

  def generate
    Tempfile.create([ "estimate", ".json" ]) do |input|
      Tempfile.create([ "estimate", ".pdf" ]) do |output|
        input.write(JSON.generate(document_data))
        input.flush

        _stdout, stderr, status = Open3.capture3(
          invoice_command,
          "estimate",
          "--import", input.path,
          "--output", output.path
        )
        raise GenerationError, stderr.presence || "見積書PDFを生成できませんでした" unless status.success?

        output.binmode
        output.rewind
        output.read
      end
    end
  rescue Errno::ENOENT => e
    raise GenerationError, "invoiceコマンドが見つかりません: #{e.message}"
  end

  private

  attr_reader :estimate

  def invoice_command
    ENV.fetch("INVOICE_COMMAND", Rails.root.join("invoice", "invoice").to_s)
  end

  def document_data
    {
      id: estimate.estimate_number,
      title: "見積書",
      from: estimate.issuer,
      to: estimate.recipient,
      date: estimate.issued_on.strftime("%Y/%m/%d"),
      due: estimate.valid_until.strftime("%Y/%m/%d"),
      currency: "JPY",
      items: estimate.estimate_items.map(&:description),
      quantities: estimate.estimate_items.map(&:quantity),
      rates: estimate.estimate_items.map { |item| item.unit_price.to_f },
      tax: (estimate.tax_rate.to_d / 100).to_f,
      note: estimate.note.to_s
    }
  end
end
