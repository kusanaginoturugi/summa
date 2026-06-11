accounts = [
  # 資産
  ["101", "現金", :asset],
  ["102", "普通預金", :asset],
  ["10201", "普通預金（三菱UFJ）", :asset, "102"],
  ["10202", "普通預金（みずほ）", :asset, "102"],
  ["10203", "普通預金（楽天銀行）", :asset, "102"],
  ["103", "当座預金", :asset],
  ["105", "受取手形", :asset],
  ["106", "売掛金", :asset],
  ["108", "商品", :asset],
  ["110", "立替金", :asset],
  ["111", "前払費用", :asset],
  ["113", "未収入金", :asset],
  ["114", "貸付金", :asset],
  ["116", "建物", :asset],
  ["117", "車両運搬具", :asset],
  ["118", "工具器具備品", :asset],

  # 負債
  ["201", "支払手形", :liability],
  ["202", "買掛金", :liability],
  ["203", "未払金", :liability],
  ["204", "未払費用", :liability],
  ["205", "前受金", :liability],
  ["206", "短期借入金", :liability],
  ["207", "長期借入金", :liability],
  ["208", "預り金", :liability],
  ["210", "仮受消費税", :liability],

  # 純資産（個人事業主向け）
  ["301", "元入金", :equity],
  ["302", "事業主借", :equity],
  ["303", "事業主貸", :equity],

  # 収益
  ["401", "売上高", :revenue],
  ["402", "受取利息", :revenue],
  ["403", "雑収入", :revenue],

  # 費用
  ["501", "仕入高", :expense],
  ["502", "給料賃金", :expense],
  ["503", "外注工賃", :expense],
  ["504", "旅費交通費", :expense],
  ["505", "通信費", :expense],
  ["506", "広告宣伝費", :expense],
  ["507", "支払手数料", :expense],
  ["508", "水道光熱費", :expense],
  ["509", "租税公課", :expense],
  ["510", "減価償却費", :expense],
  ["511", "福利厚生費", :expense],
  ["512", "保険料", :expense],
  ["513", "消耗品費", :expense],
  ["514", "地代家賃", :expense],
  ["515", "修繕費", :expense],
  ["516", "新聞図書費", :expense],
  ["520", "雑費", :expense],
  ["999", "貸借不一致", :expense]
]

accounts.each do |code, name, category, parent_code|
  Account.find_or_create_by!(code: code) do |account|
    account.name = name
    account.category = category
    account.parent_code = parent_code
  end
end
