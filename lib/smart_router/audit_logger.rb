# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # AuditLogger stores structured decision logs for full auditability and regulatory compliance.
  class AuditLogger
    attr_reader :logs

    def initialize
      @logs = []
    end

    def log_attempt(operation_id:, provider:, decision:, reason:, details: nil, score: nil)
      entry = {
        timestamp: Time.now.utc.iso8601,
        operation_id: operation_id,
        provider: provider,
        decision: decision, # 'selected' or 'skipped'
        reason: reason,
        details: details,
        score: score ? score.round(4) : nil
      }.compact

      @logs << entry
      entry
    end

    def find_by_operation(operation_id)
      @logs.select { |l| l[:operation_id] == operation_id }
    end

    def export_summary
      {
        total_logged_attempts: @logs.size,
        total_selected: @logs.count { |l| l[:decision] == 'selected' },
        total_skipped: @logs.count { |l| l[:decision] == 'skipped' },
        skip_reasons_tally: @logs.select { |l| l[:decision] == 'skipped' }.group_by { |l| l[:reason] }.transform_values(&:count)
      }
    end
  end
end
