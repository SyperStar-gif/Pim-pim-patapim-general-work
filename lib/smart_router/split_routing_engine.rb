# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # SplitRoutingEngine handles batch splitting of large-amount single transactions
  # into multiple sub-operations routed across diverse providers to avoid hitting
  # individual transaction maximums or daily thresholds.
  class SplitRoutingEngine
    attr_reader :router

    def initialize(router)
      @router = router
    end

    def can_route_whole?(amount)
      providers = @router.providers.values.reject(&:is_fallback).select(&:active?)
      providers.any? { |p| p.limit_amount_max >= amount && p.limit_amount_min <= amount }
    end

    def split_and_route(parent_operation)
      parent_amt = parent_operation['amount'].to_f
      op_id = parent_operation['operation_id']
      bank = parent_operation['bank']

      # If already routable without split, route directly
      if can_route_whole?(parent_amt)
        return {
          split_required: false,
          sub_decisions: [@router.route_single(parent_operation)]
        }
      end

      # Find highest allowed chunk
      active_provs = @router.providers.values.reject(&:is_fallback).select(&:active?)
      max_chunk = active_provs.map(&:limit_amount_max).max || 50_000.0

      chunks = []
      remaining = parent_amt
      idx = 1

      while remaining > 0
        chunk_amt = [remaining, max_chunk].min
        chunks << {
          'operation_id' => "#{op_id}_part_#{idx}",
          'amount' => chunk_amt,
          'bank' => bank,
          'parent_operation_id' => op_id
        }
        remaining = (remaining - chunk_amt).round(2)
        idx += 1
      end

      sub_decisions = chunks.map { |chunk_op| @router.route_single(chunk_op) }

      {
        split_required: true,
        parent_operation_id: op_id,
        parent_amount: parent_amt,
        parts_count: chunks.size,
        sub_decisions: sub_decisions,
        all_approved: sub_decisions.all? { |d| d['simulated_result'] == 'approved' }
      }
    end
  end
end
