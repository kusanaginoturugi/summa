require "test_helper"

class EstimatePdfServiceTest < ActiveSupport::TestCase
  test "builds invoice input with a numeric tax rate" do
    estimate = Estimate.new(
      estimate_number: "EST-001",
      issued_on: Date.new(2026, 6, 11),
      valid_until: Date.new(2026, 7, 11),
      issuer: "株式会社テスト",
      recipient: "山田太郎",
      tax_rate: 10,
      note: "備考"
    )
    estimate.estimate_items.build(description: "作業費", quantity: 1, unit_price: 50_000)

    data = EstimatePdfService.new(estimate).send(:document_data)

    assert_equal 0.1, data[:tax]
    assert_equal [ "作業費" ], data[:items]
    assert_equal [ 50_000.0 ], data[:rates]
  end
end
