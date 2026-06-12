class Estimate < ApplicationRecord
  has_many :estimate_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :estimate

  accepts_nested_attributes_for :estimate_items, reject_if: :all_blank, allow_destroy: true

  validates :estimate_number, :issued_on, :valid_until, :issuer, :recipient, presence: true
  validates :estimate_number, uniqueness: true
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0 }
  validate :has_items
  validate :valid_until_is_not_before_issued_on

  before_validation :assign_item_positions

  def subtotal
    estimate_items.sum(&:amount)
  end

  def tax_amount
    (subtotal * tax_rate.to_d / 100).round
  end

  def total
    subtotal + tax_amount
  end

  private

  def assign_item_positions
    estimate_items.reject(&:marked_for_destruction?).each_with_index do |item, index|
      item.position = index
    end
  end

  def has_items
    return if estimate_items.any? { |item| !item.marked_for_destruction? && item.description.present? }

    errors.add(:estimate_items, "を1件以上入力してください")
  end

  def valid_until_is_not_before_issued_on
    return if issued_on.blank? || valid_until.blank? || valid_until >= issued_on

    errors.add(:valid_until, "は発行日以降の日付にしてください")
  end
end
