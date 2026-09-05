# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # DynamicFeeModel computes tiered, progressive, or fixed-plus-percentage fee structures
  # commonly used by payment gateways, calculating real net payout amounts.
  class DynamicFeeModel
    FEE_TYPES = %i[flat percentage tiered fixed_plus_pct].freeze

    attr_reader :provider_fee_structures

    def initialize(structures = {})
      @provider_fee_structures = structures
    end

    def set_structure(provider_id, type:, fixed_fee: 0.0, pct_fee: 0.0, tiers: nil)
      @provider_fee_structures[provider_id.to_s] = {
        type: type,
        fixed_fee: PrecisionMath.to_d(fixed_fee),
        pct_fee: PrecisionMath.to_d(pct_fee),
        tiers: tiers
      }
    end

    def calculate_fee(provider_id, amount)
      amt_d = PrecisionMath.to_d(amount)
      cfg = @provider_fee_structures[provider_id.to_s]

      return (amt_d * BigDecimal('0.02')).to_f.round(2) unless cfg # default 2% fallback

      fee = case cfg[:type]
            when :flat
              cfg[:fixed_fee]
            when :percentage
              amt_d * (cfg[:pct_fee] / BigDecimal(100))
            when :fixed_plus_pct
              cfg[:fixed_fee] + (amt_d * (cfg[:pct_fee] / BigDecimal(100)))
            when :tiered
              calculate_tiered_fee(amt_d, cfg[:tiers])
            else
              amt_d * (cfg[:pct_fee] / BigDecimal(100))
            end

      fee.to_f.round(2)
    end

    def calculate_net_payout(provider_id, amount)
      amt = PrecisionMath.to_d(amount).to_f
      fee = calculate_fee(provider_id, amount)
      (amt - fee).round(2)
    end

    private

    def calculate_tiered_fee(amount, tiers)
      return BigDecimal(0) unless tiers&.any?

      matching_tier = tiers.find do |t|
        min = PrecisionMath.to_d(t['min'] || 0)
        max = PrecisionMath.to_d(t['max'] || Float::INFINITY)
        amount >= min && amount <= max
      end

      return amount * BigDecimal('0.02') unless matching_tier

      pct = PrecisionMath.to_d(matching_tier['pct'] || 2.0)
      amount * (pct / BigDecimal(100))
    end
  end
end
