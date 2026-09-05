# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # CostOptimizer determines routing priority to minimize merchant interchange
  # and processing commissions while maintaining SLA reliability.
  class CostOptimizer
    attr_reader :providers

    def initialize(providers)
      @providers = providers
    end

    def rank_by_lowest_cost(eligible_candidates, amount)
      amt_d = PrecisionMath.to_d(amount)

      ranked = eligible_candidates.map do |provider|
        fee_pct = PrecisionMath.to_d(provider.provider_margin_pct)
        estimated_fee = (amt_d * (fee_pct / 100.0)).to_f.round(2)
        conversion = provider.conversion_24h.to_f

        # Cost-efficiency ratio: lower fee is better, penalized by unreliability
        # Higher score = more cost efficient
        cost_score = (100.0 - (fee_pct * 10.0)) * conversion

        {
          provider: provider,
          estimated_fee_rub: estimated_fee,
          fee_pct: fee_pct.to_f,
          conversion: conversion,
          cost_score: cost_score.round(3)
        }
      end

      ranked.sort_by { |item| -item[:cost_score] }
    end

    def estimate_potential_savings(operation_queue)
      # Calculates potential fee savings comparing cheapest vs most expensive eligible providers
      total_min_fee = 0.0
      total_max_fee = 0.0

      operation_queue.each do |op|
        amt = op['amount'].to_f
        fees = @providers.values.reject(&:is_fallback).map do |p|
          amt * (p.provider_margin_pct / 100.0)
        end
        total_min_fee += fees.min || 0.0
        total_max_fee += fees.max || 0.0
      end

      {
        total_min_fee_rub: total_min_fee.round(2),
        total_max_fee_rub: total_max_fee.round(2),
        potential_savings_rub: (total_max_fee - total_min_fee).round(2),
        potential_savings_pct: total_max_fee.positive? ? (((total_max_fee - total_min_fee) / total_max_fee) * 100).round(1) : 0.0
      }
    end
  end
end
