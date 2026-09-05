# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # SelfHealingEngine dynamically reacts to repeated failure patterns
  # by auto-adjusting weights, throttling unviable providers, and repairing cascades.
  class SelfHealingEngine
    attr_reader :quarantine_list, :throttle_factors, :action_log

    def initialize
      @quarantine_list = {}
      @throttle_factors = Hash.new(1.0)
      @action_log = []
    end

    def record_outcome(provider_id, success, latency_sec = nil)
      pid = provider_id.to_s
      if success
        # Gradually heal throttle factor back towards 1.0
        if @throttle_factors[pid] < 1.0
          @throttle_factors[pid] = [@throttle_factors[pid] + 0.1, 1.0].min.round(2)
        end
      else
        # Degrade throttle factor
        @throttle_factors[pid] = [@throttle_factors[pid] - 0.25, 0.1].max.round(2)
        log_action("Degraded throttle factor for #{pid} to #{@throttle_factors[pid]}")
      end

      # High latency penalty
      if latency_sec && latency_sec > 45.0
        @throttle_factors[pid] = [@throttle_factors[pid] - 0.15, 0.1].max.round(2)
        log_action("Latency penalty applied to #{pid} (#{latency_sec}s > 45s)")
      end
    end

    def quarantine!(provider_id, duration_sec = 60, reason = 'excessive_failures')
      pid = provider_id.to_s
      release_time = Time.now + duration_sec
      @quarantine_list[pid] = {
        release_at: release_time,
        reason: reason
      }
      log_action("Quarantined #{pid} for #{duration_sec}s due to #{reason}")
    end

    def quarantined?(provider_id)
      pid = provider_id.to_s
      entry = @quarantine_list[pid]
      return false unless entry

      if Time.now >= entry[:release_at]
        @quarantine_list.delete(pid)
        log_action("Quarantine expired for #{pid}, returning to service")
        false
      else
        true
      end
    end

    def effective_multiplier(provider_id)
      return 0.0 if quarantined?(provider_id)

      @throttle_factors[provider_id.to_s]
    end

    private

    def log_action(message)
      @action_log << {
        timestamp: Time.now.utc.iso8601,
        message: message
      }
    end
  end
end
