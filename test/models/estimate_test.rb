require "test_helper"

class EstimateTest < ActiveSupport::TestCase
  test "calculates subtotal tax and total" do
    estimate = Estimate.new(
      estimate_number: "EST-001",
      issued_on: Date.new(2026, 6, 11),
      valid_until: Date.new(2026, 7, 11),
      issuer: "株式会社テスト",
      recipient: "山田太郎",
      tax_rate: 10
    )
    estimate.estimate_items.build(description: "作業費", quantity: 2, unit_price: 25_000)

    assert_equal 50_000, estimate.subtotal
    assert_equal 5_000, estimate.tax_amount
    assert_equal 55_000, estimate.total
  end

  test "requires at least one item" do
    estimate = Estimate.new(
      estimate_number: "EST-002",
      issued_on: Date.new(2026, 6, 11),
      valid_until: Date.new(2026, 7, 11),
      issuer: "株式会社テスト",
      recipient: "山田太郎"
    )

    assert_not estimate.valid?
    assert estimate.errors[:estimate_items].present?
  end
end
