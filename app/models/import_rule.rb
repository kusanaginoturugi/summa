class ImportRule < ApplicationRecord
  MATCH_TYPES = %w[contains prefix exact].freeze
  DIRECTIONS = %w[deposit withdrawal both].freeze

  validates :keyword, presence: true, uniqueness: { scope: :direction }
  validates :account_code, presence: true
  validates :match_type, inclusion: { in: MATCH_TYPES }
  validates :direction, inclusion: { in: DIRECTIONS }

  def self.record_from_voucher(voucher)
    return if voucher.nil?

    keyword = voucher.description.to_s.strip
    return if keyword.blank?

    debit_codes = voucher.voucher_lines.select { |line| line.debit_amount.to_d.positive? }
                                       .map(&:account_code).compact.uniq
    credit_codes = voucher.voucher_lines.select { |line| line.credit_amount.to_d.positive? }
                                        .map(&:account_code).compact.uniq
    return unless debit_codes.size == 1 && credit_codes.size == 1

    create_or_update_rule(keyword, "deposit", credit_codes.first)
    create_or_update_rule(keyword, "withdrawal", debit_codes.first)
  rescue StandardError => e
    Rails.logger.warn("[ImportRule] failed to record from voucher #{voucher&.id}: #{e.class} #{e.message}")
    nil
  end

  def self.create_or_update_rule(keyword, direction, account_code)
    return if account_code.blank?

    rule = find_or_initialize_by(keyword: keyword, direction: direction)
    rule.account_code = account_code
    rule.match_type = rule.match_type.presence || "contains"
    rule.priority = rule.priority.presence || 100
    rule.save!
  end

  def self.match_for(description, direction)
    text = description.to_s.downcase
    rules = where(direction: [direction, "both"]).order(:priority, :id)
    rules.find do |rule|
      key = rule.keyword.downcase
      case rule.match_type
      when "exact"
        text == key
      when "prefix"
        text.start_with?(key)
      else
        text.include?(key)
      end
    end
  end
end
