# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # RequisiteOptimizer tracks and dynamically assigns banking terminal requisites
  # to maximize concurrent throughput without exceeding terminal limits.
  class RequisiteOptimizer
    attr_reader :terminals, :lock_table

    def initialize(initial_requisites = {})
      @terminals = {}
      @lock_table = {}

      initial_requisites.each do |prov_id, count|
        @terminals[prov_id.to_s] = {
          total: count.to_i,
          available: count.to_i,
          locked: 0
        }
      end
    end

    def acquire_requisite(provider_id, operation_id)
      entry = @terminals[provider_id.to_s]
      return false unless entry && entry[:available].positive?

      entry[:available] -= 1
      entry[:locked] += 1
      @lock_table[operation_id.to_s] = provider_id.to_s
      true
    end

    def release_requisite(operation_id)
      prov_id = @lock_table.delete(operation_id.to_s)
      return false unless prov_id

      entry = @terminals[prov_id]
      if entry && entry[:locked].positive?
        entry[:locked] -= 1
        entry[:available] += 1
      end
      true
    end

    def utilization_pct(provider_id)
      entry = @terminals[provider_id.to_s]
      return 0.0 unless entry && entry[:total].positive?

      ((entry[:locked] / entry[:total].to_f) * 100.0).round(2)
    end
  end
end
