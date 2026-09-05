# frozen_string_literal: true

require 'json'
require 'csv'
require 'time'

module SmartRouter
  # HistoricalAnalyzer processes operations_history.csv to extract empirical
  # provider performance metrics, volume distribution, and routing calibration baseline.
  class HistoricalAnalyzer
    attr_reader :csv_path, :records, :providers_summary

    def initialize(csv_path = File.expand_path('../../data/operations_history.csv', __dir__))
      @csv_path = csv_path
      @records = []
      @providers_summary = {}
      load_history if File.exist?(@csv_path)
    end

    def load_history
      @records = []
      CSV.foreach(@csv_path, headers: true) do |row|
        @records << {
          operation_id: row['operation_id'],
          provider: row['provider'],
          amount: row['amount'].to_f,
          bank: row['bank'],
          status: row['status'] || row['simulated_result'],
          latency: (row['latency_sec'] || row['latency']).to_f,
          timestamp: row['created_at'] || row['timestamp']
        }
      end
      compute_summary
    end

    def compute_summary
      @providers_summary = {}
      total_ops = @records.size
      total_vol = @records.sum { |r| r[:amount] }

      grouped = @records.group_by { |r| r[:provider] }
      grouped.each do |provider, list|
        approved = list.select { |r| r[:status] == 'approved' }
        rejected = list.select { |r| r[:status] == 'rejected' }
        prov_vol = list.sum { |r| r[:amount] }
        prov_approved_vol = approved.sum { |r| r[:amount] }
        avg_latency = list.any? ? (list.sum { |r| r[:latency] } / list.size.to_f).round(2) : 0.0

        @providers_summary[provider] = {
          total_operations: list.size,
          approved_operations: approved.size,
          rejected_operations: rejected.size,
          total_volume: prov_vol.round(2),
          approved_volume: prov_approved_vol.round(2),
          count_share_pct: total_ops.positive? ? ((list.size / total_ops.to_f) * 100).round(2) : 0.0,
          volume_share_pct: total_vol.positive? ? ((prov_vol / total_vol) * 100).round(2) : 0.0,
          empirical_conversion_pct: list.any? ? ((approved.size / list.size.to_f) * 100).round(2) : 0.0,
          average_latency_sec: avg_latency,
          banks_handled: list.map { |r| r[:bank] }.compact.uniq
        }
      end
      @providers_summary
    end

    # Computes volume tiers across the historical dataset
    def volume_tiers_breakdown
      tiers = {
        micro: { min: 0, max: 1_000, count: 0, volume: 0.0 },
        small: { min: 1_001, max: 20_000, count: 0, volume: 0.0 },
        medium: { min: 20_001, max: 75_000, count: 0, volume: 0.0 },
        large: { min: 75_001, max: 300_000, count: 0, volume: 0.0 },
        enterprise: { min: 300_001, max: Float::INFINITY, count: 0, volume: 0.0 }
      }

      @records.each do |r|
        amt = r[:amount]
        tiers.each_value do |tier|
          if amt >= tier[:min] && amt <= tier[:max]
            tier[:count] += 1
            tier[:volume] += amt
            break
          end
        end
      end
      tiers
    end

    # Recommendations based on historical telemetry
    def generate_calibration_recommendations(current_providers = {})
      recs = []
      @providers_summary.each do |pname, data|
        prov_cfg = current_providers[pname]
        next unless prov_cfg

        # Check conversion discrepancy
        cfg_conv = prov_cfg['conversion_24h'].to_f * 100
        emp_conv = data[:empirical_conversion_pct]
        if (cfg_conv - emp_conv).abs > 15.0
          recs << "Провайдер #{pname}: историческая конверсия (#{emp_conv}%) существенно отличается от conversion_24h (#{cfg_conv}%). Рекомендуется обновить метрику."
        end

        # Check volume skew
        target_vol = prov_cfg['volume_share_pct']&.to_f || prov_cfg['traffic_percentage']&.to_f || 0.0
        actual_vol = data[:volume_share_pct]
        if (actual_vol - target_vol).abs > 20.0
          recs << "Провайдер #{pname}: историческая доля объёма (#{actual_vol}%) имеет сильное отклонение от целевой (#{target_vol}%)."
        end
      end
      recs
    end
  end
end
