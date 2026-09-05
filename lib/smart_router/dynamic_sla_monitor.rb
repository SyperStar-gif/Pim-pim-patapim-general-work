# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # DynamicSlaMonitor tracks 99th percentile SLA compliance, response times,
  # and failure rates against contractual partner commitments.
  class DynamicSlaMonitor
    attr_reader :sla_targets, :history

    DEFAULT_SLA = {
      target_conversion_pct: 85.0,
      target_latency_p90_sec: 30.0,
      target_latency_max_sec: 60.0,
      max_rejection_rate_pct: 15.0
    }.freeze

    def initialize(sla_targets = nil)
      @sla_targets = sla_targets || DEFAULT_SLA.dup
      @history = Hash.new { |h, k| h[k] = [] }
    end

    def record_operation(provider_id, result, latency_sec)
      pid = provider_id.to_s
      @history[pid] << {
        result: result, # 'approved', 'rejected', 'expired'
        latency: latency_sec.to_f,
        timestamp: Time.now
      }
    end

    def evaluate_compliance(provider_id)
      pid = provider_id.to_s
      records = @history[pid]
      return { status: :no_data, compliance_pct: 100.0, breaches: [] } if records.empty?

      total = records.size
      approved = records.count { |r| r[:result] == 'approved' }
      conversion = ((approved / total.to_f) * 100).round(2)

      latencies = records.map { |r| r[:latency] }.sort
      p90_idx = [(0.90 * total).ceil - 1, 0].max
      p90_latency = latencies[p90_idx].round(2)
      max_latency = latencies.max.round(2)

      breaches = []
      breaches << "Низкая конверсия (#{conversion}% < #{@sla_targets[:target_conversion_pct]}%)" if conversion < @sla_targets[:target_conversion_pct]
      breaches << "Превышена P90 задержка (#{p90_latency}s > #{@sla_targets[:target_latency_p90_sec]}s)" if p90_latency > @sla_targets[:target_latency_p90_sec]
      breaches << "Превышена максимальная задержка (#{max_latency}s > #{@sla_targets[:target_latency_max_sec]}s)" if max_latency > @sla_targets[:target_latency_max_sec]

      compliance_score = [100.0 - (breaches.size * 25.0), 0.0].max

      {
        provider_id: pid,
        total_operations: total,
        conversion_pct: conversion,
        p90_latency_sec: p90_latency,
        max_latency_sec: max_latency,
        breaches: breaches,
        compliant: breaches.empty?,
        compliance_pct: compliance_score
      }
    end
  end
end
