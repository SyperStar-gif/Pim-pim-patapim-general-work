# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # AnomalyDetector monitors runtime distribution patterns and triggers alerts
  # when starvation, concentration risk, or abnormal error rates are detected.
  class AnomalyDetector
    attr_reader :alerts

    STARVATION_THRESHOLD_PCT = 5.0 # provider getting less than 5% when target > 20%
    CONCENTRATION_THRESHOLD_PCT = 85.0 # single provider capturing > 85% volume
    REJECTION_SPIKE_THRESHOLD_PCT = 40.0 # rejection rate > 40%

    def initialize
      @alerts = []
    end

    def inspect_routing_state(providers, total_operations, total_volume)
      @alerts = []
      return @alerts if total_operations.zero?

      providers.each_value do |prov|
        next if prov.is_fallback

        # 1. Starvation detection
        if prov.traffic_percentage >= 20.0
          actual_share = (prov.processed_count / total_operations.to_f) * 100.0
          if actual_share < STARVATION_THRESHOLD_PCT
            @alerts << {
              type: 'traffic_starvation',
              severity: 'warning',
              provider: prov.id,
              message: "Провайдер #{prov.id} недополучает трафик (факт #{actual_share.round(1)}% при цели #{prov.traffic_percentage}%)",
              details: { actual_share_pct: actual_share.round(2), target_share_pct: prov.traffic_percentage }
            }
          end
        end

        # 2. High rejection spike detection
        total_prov_attempts = prov.successful_count + prov.failed_count
        if total_prov_attempts >= 5
          rejection_pct = (prov.failed_count / total_prov_attempts.to_f) * 100.0
          if rejection_pct >= REJECTION_SPIKE_THRESHOLD_PCT
            @alerts << {
              type: 'rejection_spike',
              severity: 'critical',
              provider: prov.id,
              message: "Всплеск отказов у #{prov.id}: #{rejection_pct.round(1)}% неудачных попыток (#{prov.failed_count}/#{total_prov_attempts})",
              details: { failed_count: prov.failed_count, total_count: total_prov_attempts }
            }
          end
        end

        # 3. Approaching daily limit
        utilization = prov.daily_utilization_pct
        if utilization >= 90.0 && utilization < 100.0
          @alerts << {
            type: 'daily_limit_near_exhaustion',
            severity: 'warning',
            provider: prov.id,
            message: "Провайдер #{prov.id} исчерпал #{utilization.round(1)}% суточного лимита",
            details: { daily_approved: prov.daily_approved_amount, daily_limit: prov.daily_amount_limit }
          }
        end
      end

      # 4. Volume concentration risk
      if total_volume.positive?
        providers.each_value do |prov|
          prov_vol_share = (prov.processed_volume / total_volume) * 100.0
          if prov_vol_share >= CONCENTRATION_THRESHOLD_PCT && providers.size > 2
            @alerts << {
              type: 'concentration_risk',
              severity: 'warning',
              provider: prov.id,
              message: "Высокая концентрация оборота на #{prov.id} (#{prov_vol_share.round(1)}% общего объема)",
              details: { volume_share_pct: prov_vol_share.round(2) }
            }
          end
        end
      end

      @alerts
    end
  end
end
