# frozen_string_literal: true

module SmartRouter
  class SimulationEngine
    attr_accessor :deterministic_seed

    def initialize(seed: 42)
      @random = Random.new(seed)
    end

    # Simulates transaction processing by a provider
    # Returns [result: String ('approved' | 'rejected' | 'expired'), latency_sec: Integer, error_detail: String]
    def execute_attempt(provider, operation)
      # Deterministic pseudo-random based on operation_id and provider for reproducible validation
      hash_val = (operation.operation_id.hash ^ provider.id.hash).abs
      roll = (hash_val % 1000) / 1000.0

      # Realistic latency around avg_latency_sec
      jitter = (hash_val % 7) - 3
      latency = [provider.avg_latency_sec + jitter, 5].max

      threshold = provider.conversion_24h

      if roll <= threshold
        ['approved', latency, nil]
      elsif roll <= threshold + 0.05
        ['expired', [latency + 15, 60].min, 'Gateway timeout after 60s']
      else
        ['rejected', latency, 'Bank decline code 05: Do Not Honor']
      end
    end
  end
end
