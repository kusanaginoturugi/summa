require "test_helper"

class BankImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Account.find_or_create_by!(code: "102") do |account|
      account.name = "普通預金"
      account.category = "asset"
    end
    Account.find_or_create_by!(code: "401") do |account|
      account.name = "売上高"
      account.category = "revenue"
    end
    Account.find_or_create_by!(code: "520") do |account|
      account.name = "雑費"
      account.category = "expense"
    end
  end

  test "shows import rules with missing accounts" do
    ImportRule.create!(
      keyword: "古い摘要",
      direction: "withdrawal",
      account_code: "11902",
      match_type: "contains",
      priority: 100
    )

    get new_bank_import_path

    assert_response :success
    assert_select "h2", "無効な取込ルール"
    assert_select "td", "古い摘要"
    assert_select "td", "11902"
  end

  test "deletes import rules with missing accounts" do
    ImportRule.create!(
      keyword: "古い摘要",
      direction: "withdrawal",
      account_code: "11902",
      match_type: "contains",
      priority: 100
    )
    ImportRule.create!(
      keyword: "売上",
      direction: "deposit",
      account_code: "401",
      match_type: "contains",
      priority: 100
    )

    assert_difference("ImportRule.count", -1) do
      delete invalid_import_rules_bank_imports_path
    end

    assert_redirected_to new_bank_import_path
    assert_nil ImportRule.find_by(account_code: "11902")
    assert ImportRule.exists?(account_code: "401")
  end
end
