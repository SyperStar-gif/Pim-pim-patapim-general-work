# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # FraudAndRiskScorer evaluates individual transactions for velocity anomalies,
  # suspicious amount spikes, or risky card-issuing bins before routing.
  class FraudAndRiskScorer
    RISK_LEVELS = %i[low medium high critical].freeze

    attr_reader :velocity_window_sec, :max_ops_per_window, :seen_operations

    def initialize(velocity_window_sec: 60, max_ops_per_window: 10)
      @velocity_window_sec = velocity_window_sec
      @max_ops_per_window = max_ops_per_window
      @seen_operations = []
    end

    def assess_risk(operation_hash)
      now = Time.now
      prune_expired_history(now)

      op_id = operation_hash['operation_id'] || operation_hash[:operation_id]
      amount = PrecisionMath.to_d(operation_hash['amount'] || operation_hash[:amount]).to_f
      bank = (operation_hash['bank'] || operation_hash[:bank]).to_s.downcase

      @seen_operations << { id: op_id, amount: amount, bank: bank, timestamp: now }

      risk_score = 0.0
      factors = []

      # Factor 1: Transaction Velocity spike
      ops_in_window = @seen_operations.size
      if ops_in_window > @max_ops_per_window
        risk_score += 35.0
        factors << "Высокая интенсивность операций: #{ops_in_window} за #{@velocity_window_sec}с"
      end

      # Factor 2: High Amount Outlier (> 250,000 RUB)
      if amount > 250_000.0
        risk_score += 25.0
        factors << "Крупная сумма чека (#{amount.to_i} ₽)"
      elsif amount < 10.0 && amount.positive?
        risk_score += 15.0
        factors << "Подозрительно низкий микро-чек (#{amount} ₽ - card testing)"
      end

      # Factor 3: Bank classification
      if %w[crypto_bank foreign_bank offshore].include?(bank)
        risk_score += 40.0
        factors << "Высокорисковый банк-эмитент: #{bank}"
      end

      level = determine_level(risk_score)

      {
        operation_id: op_id,
        risk_score: [risk_score, 100.0].min.round(1),
        risk_level: level,
        allow_routing: level != :critical,
        require_high_conversion_provider: [:medium, :high].include?(level),
        factors: factors
      }
    end

    private

    def prune_expired_history(now)
      cutoff = now - @velocity_window_sec
      @seen_operations.reject! { |op| op[:timestamp] < cutoff }
    end

    def determine_level(score)
      if score >= 70.0
        :critical
      elsif score >= 40.0
        :high
      elsif score >= 20.0
        :medium
      else
        :low
      end
    end
  end
end
