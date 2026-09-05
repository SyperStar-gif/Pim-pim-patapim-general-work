# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # RoutingPolicyConfig manages business rules, strategy profiles, and priority overrides.
  class RoutingPolicyConfig
    DEFAULT_CONFIG = {
      'strategy' => 'combined',
      'weights' => {
        'traffic_share' => 0.25,
        'volume_share' => 0.20,
        'conversion' => 0.20,
        'financial_obligations' => 0.15,
        'amount_tier' => 0.10,
        'priority' => 0.05,
        'load_balance' => 0.05
      },
      'fallback_provider' => 'spacepayments',
      'enable_anomaly_detection' => true,
      'allow_negative_margin' => false,
      'cascade_max_attempts' => 5
    }.freeze

    attr_accessor :config

    def initialize(initial_hash = nil)
      @config = deep_copy(DEFAULT_CONFIG)
      merge!(initial_hash) if initial_hash
    end

    def self.load_from_file(filepath)
      if File.exist?(filepath)
        data = JSON.parse(File.read(filepath))
        new(data)
      else
        new
      end
    end

    def save_to_file(filepath)
      File.write(filepath, JSON.pretty_generate(@config))
    end

    def merge!(other_hash)
      return unless other_hash.is_a?(Hash)

      other_hash.each do |k, v|
        if v.is_a?(Hash) && @config[k.to_s].is_a?(Hash)
          @config[k.to_s].merge!(v.transform_keys(&:to_s))
        else
          @config[k.to_s] = v
        end
      end
    end

    def strategy
      @config['strategy']
    end

    def weights
      (@config['weights'] || {}).transform_keys(&:to_sym)
    end

    def fallback_provider_id
      @config['fallback_provider'] || 'spacepayments'
    end

    private

    def deep_copy(obj)
      Marshal.load(Marshal.dump(obj))
    end
  end
end
