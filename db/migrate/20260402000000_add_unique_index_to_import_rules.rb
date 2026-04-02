class AddUniqueIndexToImportRules < ActiveRecord::Migration[8.1]
  def change
    # 既存の非ユニークインデックスをユニーク制約付きに置き換える。
    # これにより find_or_initialize_by の競合状態でも重複レコードが作られない。
    remove_index :import_rules, name: "index_import_rules_on_keyword_and_direction"
    add_index :import_rules, [:keyword, :direction], unique: true,
              name: "index_import_rules_on_keyword_and_direction"
  end
end
