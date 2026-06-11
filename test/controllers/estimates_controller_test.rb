require "test_helper"

class EstimatesControllerTest < ActionDispatch::IntegrationTest
  test "shows estimate list" do
    get estimates_path

    assert_response :success
    assert_select "h1", "見積書一覧"
    assert_select "a", "見積書作成"
  end

  test "creates an estimate" do
    assert_difference([ "Estimate.count", "EstimateItem.count" ], 1) do
      post estimates_path, params: {
        estimate: {
          estimate_number: "EST-20260611-001",
          issued_on: "2026-06-11",
          valid_until: "2026-07-11",
          issuer: "株式会社テスト",
          recipient: "山田太郎",
          tax_rate: "10",
          note: "備考",
          estimate_items_attributes: {
            "0" => {
              description: "作業費",
              quantity: "1",
              unit_price: "50000"
            }
          }
        }
      }
    end

    assert_redirected_to estimates_path
  end
end
