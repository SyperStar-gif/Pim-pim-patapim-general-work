# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # MachineReadableReporter produces rich diagnostic breakdowns for compliance,
  # auditing, and automatic pipeline evaluation.
  class MachineReadableReporter
    attr_reader :decisions, :report

    def initialize(decisions, report)
      @decisions = decisions || []
      @report = report || {}
    end

    def generate_extended_diagnostics
      total = @decisions.size
      return empty_diagnostics if total.zero?

      approved = @decisions.select { |d| d['simulated_result'] == 'approved' }
      rejected = @decisions.select { |d| d['simulated_result'] == 'rejected' }
      expired  = @decisions.select { |d| d['simulated_result'] == 'expired' }

      latencies = @decisions.map { |d| d['latency_sec'].to_f }.compact
      avg_latency = latencies.any? ? (latencies.sum / latencies.size).round(2) : 0.0
      p95_latency = latencies.any? ? percentile(latencies, 95) : 0.0

      cascade_depths = @decisions.map { |d| Array(d['attempts']).size }
      avg_cascade_depth = cascade_depths.any? ? (cascade_depths.sum / cascade_depths.size.to_f).round(2) : 0.0
      max_cascade_depth = cascade_depths.max || 0

      # Tally all attempts across operations
      all_attempts = @decisions.flat_map { |d| Array(d['attempts']) }
      reasons_tally = all_attempts.select { |a| a['decision'] == 'skipped' }.group_by { |a| a['reason'] }.transform_values(&:count)
      selection_reasons = all_attempts.select { |a| a['decision'] == 'selected' }.group_by { |a| a['reason'] }.transform_values(&:count)

      {
        summary: {
          total_operations: total,
          approved_count: approved.size,
          rejected_count: rejected.size,
          expired_count: expired.size,
          approval_rate_pct: ((approved.size / total.to_f) * 100).round(2),
          avg_latency_sec: avg_latency,
          p95_latency_sec: p95_latency,
          avg_cascade_depth: avg_cascade_depth,
          max_cascade_depth: max_cascade_depth
        },
        distribution: @report['distribution'] || {},
        skip_reasons: reasons_tally,
        selection_reasons: selection_reasons,
        projected_daily_utilization: @report['projected_daily_utilization'] || {},
        recommendations: @report['recommendations'] || []
      }
    end

    private

    def percentile(values, pct)
      sorted = values.sort
      idx = ((pct / 100.0) * sorted.size).ceil - 1
      sorted[[idx, 0].max].round(2)
    end

    def empty_diagnostics
      {
        summary: {
          total_operations: 0,
          approved_count: 0,
          approval_rate_pct: 0.0
        },
        distribution: {},
        skip_reasons: {},
        recommendations: []
      }
    end
  end
end
