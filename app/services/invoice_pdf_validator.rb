class InvoicePdfValidator
  class Error < StandardError; end

  def self.validate!(path)
    new(path).validate!
  end

  def initialize(path)
    @path = Pathname(path)
  end

  def validate!
    raise Error, "PDFが見つかりません: #{@path}" unless @path.file?
    raise Error, "PDFが空です: #{@path}" if @path.size.zero?

    header = @path.open("rb") { |file| file.read(1024).to_s }
    raise Error, "PDFヘッダーが見つかりません: #{@path}" unless header.include?("%PDF")

    true
  end
end
