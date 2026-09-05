# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # ReplaySimulationHarness provides deterministic re-running and what-if experimentation
  # over stored operation datasets to benchmark alternative policies.
  class ReplaySimulationHarness
    attr_reader :results_by_strategy

    STRATEGIES = %w[
      combined
      traffic_share
      volume_share
      cascade_priority
      amount_tier
      conversion_boost
      rate_limit_intensity
      financial_obligations
    ].freeze

    def initialize(providers_data, operations_queue)
      @providers_data = providers_data
      @operations_queue = operations_queue
      @results_by_strategy = {}
    end

    def run_all_strategies(seed = 42)
      STRATEGIES.each do |strat|
        router = Router.new(
          deep_copy(@providers_data),
          strategy: strat,
          seed: seed
        )
        decisions = router.route_queue(@operations_queue)
        report = AnalyticsReporter.generate_report(
          decisions,
          router.providers,
          period: 'simulation'
        )

        @results_by_strategy[strat] = {
          total: decisions.size,
          approved: decisions.count { |d| d['simulated_result'] == 'approved' },
          distribution: report['distribution'],
          skip_reasons: report['skip_reasons'],
          projected_daily_utilization: report['projected_daily_utilization']
        }
      end
      @results_by_strategy
    end

    def compare_key_metrics
      comparison = {}
      @results_by_strategy.each do |strat, data|
        total = data[:total]
        approved = data[:approved]
        approval_pct = total.positive? ? ((approved / total.to_f) * 100).round(1) : 0.0

        comparison[strat] = {
          approval_rate_pct: approval_pct,
          providers_utilized: data[:distribution].keys.size
        }
      end
      comparison
    end

    private

    def deep_copy(obj)
      Marshal.load(Marshal.dump(obj))
    end
  end
end
