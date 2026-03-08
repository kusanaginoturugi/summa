class AppSetting < ApplicationRecord
  CURRENT_FISCAL_YEAR_KEY = "current_fiscal_year".freeze

  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.fetch(key, default = nil)
    setting = find_by(key: key.to_s)
    return default if setting.nil?

    setting.value
  end

  def self.write!(key, value)
    setting = find_or_initialize_by(key: key.to_s)
    setting.value = value.to_s
    setting.save!
    setting
  end

  def self.current_fiscal_year(default: Date.current.year)
    value = fetch(CURRENT_FISCAL_YEAR_KEY, default)
    year = value.to_i
    year.positive? ? year : default
  end

  def self.current_fiscal_year=(year)
    year_i = year.to_i
    raise ArgumentError, "会計年度が不正です" unless year_i.positive?

    write!(CURRENT_FISCAL_YEAR_KEY, year_i)
  end

  def self.available_fiscal_years(default_year: Date.current.year)
    min_date = Voucher.minimum(:recorded_on)
    max_date = Voucher.maximum(:recorded_on)
    years = [default_year.to_i]
    years << min_date.year if min_date.present?
    years << max_date.year if max_date.present?

    first_year = years.min
    last_year = years.max
    (first_year..last_year).to_a.reverse
  end
end
