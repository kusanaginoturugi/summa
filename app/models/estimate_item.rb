class EstimateItem < ApplicationRecord
  belongs_to :estimate, inverse_of: :estimate_items

  validates :description, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  def amount
    quantity.to_i * unit_price.to_d
  end
end
