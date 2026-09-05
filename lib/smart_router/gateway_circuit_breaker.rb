# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # GatewayCircuitBreaker prevents catastrophic cascading failures by temporarily
  # tripping open when a payment provider experiences consecutive timeouts or errors.
  class GatewayCircuitBreaker
    STATES = %i[closed open half_open].freeze

    attr_reader :failure_threshold, :recovery_timeout_sec, :breakers

    def initialize(failure_threshold: 3, recovery_timeout_sec: 30)
      @failure_threshold = failure_threshold
      @recovery_timeout_sec = recovery_timeout_sec
      @breakers = {}
    end

    def allow_request?(provider_id)
      entry = state_entry(provider_id)

      case entry[:state]
      when :closed
        true
      when :open
        if Time.now - entry[:last_failure_time] >= @recovery_timeout_sec
          entry[:state] = :half_open
          true
        else
          false
        end
      when :half_open
        true
      end
    end

    def record_success(provider_id)
      entry = state_entry(provider_id)
      entry[:state] = :closed
      entry[:consecutive_failures] = 0
    end

    def record_failure(provider_id)
      entry = state_entry(provider_id)
      entry[:consecutive_failures] += 1
      entry[:last_failure_time] = Time.now

      if entry[:consecutive_failures] >= @failure_threshold
        entry[:state] = :open
      end
    end

    def status_for(provider_id)
      entry = state_entry(provider_id)
      {
        state: entry[:state],
        consecutive_failures: entry[:consecutive_failures],
        last_failure_time: entry[:last_failure_time]
      }
    end

    private

    def state_entry(provider_id)
      @breakers[provider_id.to_s] ||= {
        state: :closed,
        consecutive_failures: 0,
        last_failure_time: Time.at(0)
      }
    end
  end
end
