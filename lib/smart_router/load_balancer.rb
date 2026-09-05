# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # LoadBalancer dynamically calculates traffic weights to minimize variance
  # between target quotas and real-time routed volume/counts.
  class LoadBalancer
    attr_reader :algorithm

    def initialize(algorithm = :weighted_deficit)
      @algorithm = algorithm
    end

    def calculate_weights(providers, total_count, total_volume)
      weights = {}

      active_providers = providers.values.reject(&:is_fallback).select(&:active?)
      return weights if active_providers.empty?

      case @algorithm
      when :weighted_deficit
        active_providers.each do |p|
          target = p.traffic_percentage
          actual = total_count.positive? ? (p.processed_count / total_count.to_f) * 100.0 : 0.0
          deficit = [target - actual, -50.0].max
          # Deficit base weight from 0.1 to 10.0
          weights[p.id] = (1.0 + (deficit / 20.0)).clamp(0.1, 10.0).round(4)
        end
      when :volume_deficit
        active_providers.each do |p|
          target = p.volume_share_pct
          actual = total_volume.positive? ? (p.processed_volume / total_volume) * 100.0 : 0.0
          deficit = target - actual
          weights[p.id] = (1.0 + (deficit / 25.0)).clamp(0.1, 10.0).round(4)
        end
      when :conversion_proportional
        active_providers.each do |p|
          conv = p.conversion_24h.to_f
          weights[p.id] = (conv * 2.0).clamp(0.1, 5.0).round(4)
        end
      else # uniform
        active_providers.each do |p|
          weights[p.id] = 1.0
        end
      end

      normalize_weights(weights)
    end

    private

    def normalize_weights(weights)
      sum = weights.values.sum
      return weights if sum.zero?

      weights.transform_values { |w| (w / sum).round(4) }
    end
  end
end
