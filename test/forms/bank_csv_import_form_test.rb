require "test_helper"

class BankCsvImportFormTest < ActiveSupport::TestCase
  setup do
    create_account!("10201", "山梨中央銀行", "asset")
    create_account!("303", "事業主貸", "equity")
    create_account!("401", "売上高", "revenue")
  end

  test "imports yamanashi bank csv with japanese headers" do
    form = BankCsvImportForm.new(
      file: csv_file,
      bank_account_code: "10201",
      deposit_counter_code: "401",
      withdrawal_counter_code: "303",
      date_column: "取扱日付",
      description_column: "摘要",
      deposit_column: "お預り金額",
      withdrawal_column: "お支払金額",
      has_header: true
    )

    assert form.parse_only, form.errors.full_messages.join(" / ")

    import = BankCsvImportForm.new(
      rows: form.rows_json,
      bank_account_code: "10201",
      deposit_counter_code: "401",
      withdrawal_counter_code: "303",
      date_column: "取扱日付",
      description_column: "摘要",
      deposit_column: "お預り金額",
      withdrawal_column: "お支払金額",
      has_header: true
    )

    assert_difference("Voucher.count", 8) do
      assert import.save, import.errors.full_messages.join(" / ")
    end
    assert_equal 8, import.created_count
    assert_equal [], VoucherLine.last(16).select { |line| line.account.blank? }
  end

  private

  def create_account!(code, name, category)
    Account.find_or_create_by!(code: code) do |account|
      account.name = name
      account.category = category
    end
  end

  def csv_file
    StringIO.new(<<~CSV)
      "番号","明細区分","取扱日付","起算日","お支払金額","お預り金額","小切手","取引区分","残高区分","残高","摘要","メモ"
      "001","","2026年5月7日","","\\200,000","","","振替支払","預金残高","\\185,218","ｵﾉｳｴ ﾀｸﾛｳ",""
      "002","","2026年5月7日","","\\275","","","振替支払","預金残高","\\184,943","ﾃｽｳﾘﾖｳ  ﾀﾞｲﾚｸﾄ",""
      "001","","2026年5月18日","","\\70,000","","","振替支払","預金残高","\\114,943","ｼﾖｳｷﾎﾞｷｷﾞﾖｳｷﾖｳｻｲ",""
      "001","","2026年5月26日","","\\67,000","","","振替支払","預金残高","\\47,943","ｶｸﾃｲｷﾖｼﾕﾂﾈﾝｷﾝｶｹｷﾝ",""
      "001","","2026年5月29日","","","\\412,500","","振込","預金残高","\\460,443","ｱﾄﾞﾊﾞﾝｽﾃｸﾉﾛｼﾞ-(ｶ",""
      "002","","2026年5月29日","","","\\220,000","","振込","預金残高","\\680,443","ｶ.ｱ-ｽﾜ-ｸｽ",""
      "001","","2026年5月31日","","\\520,000","","","振替支払","預金残高","\\160,443","ｵﾉｳｴ ﾀｸﾛｳ",""
      "002","","2026年5月31日","","\\275","","","振替支払","預金残高","\\160,168","ﾃｽｳﾘﾖｳ  ﾀﾞｲﾚｸﾄ",""
    CSV
  end
end
