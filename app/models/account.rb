class Account < ApplicationRecord
  belongs_to :parent, class_name: "Account", primary_key: :code, foreign_key: :parent_code, optional: true
  has_many :children, class_name: "Account", primary_key: :code, foreign_key: :parent_code, dependent: :nullify
  has_many :voucher_lines, primary_key: :code, foreign_key: :account_code

  CATEGORIES = %w[asset liability equity revenue expense].freeze

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  before_validation :normalize_parent

  private

  def normalize_parent
    self.parent_code = nil if parent_code.blank?
  end
end
