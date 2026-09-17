require "test_helper"

class EstimatesControllerTest < ActionDispatch::IntegrationTest
  test "shows estimate list" do
    estimate = create_estimate

    get estimates_path

    assert_response :success
    assert_select "h1", "見積書一覧"
    assert_select "a", "見積書作成"
    assert_select "a[href=?]", new_estimate_path(copy_from: estimate), "複製"
    assert_select "a[href=?]", edit_estimate_path(estimate), "編集"
  end

  test "copies an estimate into the new estimate form" do
    estimate = create_estimate(
      estimate_number: "EST-20260612-002",
      note: "支払条件を引き継ぐ"
    )

    get new_estimate_path(copy_from: estimate)

    assert_response :success
    assert_select "input[name='estimate[estimate_number]'][value=?]", "EST-#{Date.current.strftime('%Y%m%d')}-001"
    assert_select "input[name='estimate[issued_on]'][value=?]", Date.current.to_s
    assert_select "input[name='estimate[valid_until]'][value=?]", 1.month.from_now.to_date.to_s
    assert_select "textarea[name='estimate[issuer]']", "株式会社テスト"
    assert_select "textarea[name='estimate[recipient]']", "山田太郎"
    assert_select "textarea[name='estimate[note]']", "支払条件を引き継ぐ"
    assert_select "input[name='estimate[estimate_items_attributes][0][description]'][value=?]", "作業費"
    assert_select "textarea[name='estimate[estimate_items_attributes][0][detail]']", "既存の詳細"
    assert_select "input[name='estimate[estimate_items_attributes][0][quantity]'][value=?]", "1"
    assert_select "input[name='estimate[estimate_items_attributes][0][unit_price]'][value=?]", "50000.0"
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
              detail: "管理画面の改修\nPDF出力対応",
              quantity: "1",
              unit_price: "50000"
            }
          }
        }
      }
    end

    assert_redirected_to estimates_path
  end

  test "shows estimate edit form" do
    estimate = create_estimate

    get edit_estimate_path(estimate)

    assert_response :success
    assert_select "h1", "見積書編集"
    assert_select "form[action=?]", estimate_path(estimate)
    assert_select "input[name='estimate[estimate_items_attributes][0][id]'][value=?]", estimate.estimate_items.first.id.to_s
    assert_select "textarea[name='estimate[estimate_items_attributes][0][detail]']", "既存の詳細"
  end

  test "updates an estimate and its items" do
    estimate = create_estimate
    item = estimate.estimate_items.first

    assert_difference("EstimateItem.count", 0) do
      patch estimate_path(estimate), params: {
        estimate: {
          estimate_number: estimate.estimate_number,
          issued_on: "2026-06-12",
          valid_until: "2026-08-12",
          issuer: "株式会社テスト 更新後",
          recipient: "鈴木太郎",
          tax_rate: "8",
          note: "更新した備考",
          estimate_items_attributes: {
            "0" => {
              id: item.id,
              description: "削除する作業費",
              quantity: "1",
              unit_price: "50000",
              _destroy: "1"
            },
            "1" => {
              description: "更新後の作業費",
              detail: "更新後の詳細",
              quantity: "2",
              unit_price: "30000"
            }
          }
        }
      }
    end

    assert_redirected_to estimates_path
    estimate.reload
    assert_equal "鈴木太郎", estimate.recipient
    assert_equal "更新した備考", estimate.note
    assert_equal [ "更新後の作業費" ], estimate.estimate_items.pluck(:description)
    assert_equal [ "更新後の詳細" ], estimate.estimate_items.pluck(:detail)
    assert_equal 60_000, estimate.subtotal
  end

  private

  def create_estimate(estimate_number: "EST-20260612-001", note: nil)
    Estimate.create!(
      estimate_number: estimate_number,
      issued_on: Date.new(2026, 6, 12),
      valid_until: Date.new(2026, 7, 12),
      issuer: "株式会社テスト",
      recipient: "山田太郎",
      tax_rate: 10,
      note: note,
      estimate_items_attributes: {
        "0" => {
          description: "作業費",
          detail: "既存の詳細",
          quantity: 1,
          unit_price: 50_000
        }
      }
    )
  end
end
