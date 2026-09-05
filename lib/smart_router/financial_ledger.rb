# frozen_string_literal: true

require 'json'
require_relative 'precision_math'

module SmartRouter
  # FinancialLedger maintains double-entry accounting records for all routed payments,
  # merchant margin accruals, and provider fee obligations.
  class FinancialLedger
    attr_reader :transactions, :provider_balances, :merchant_profit_total

    def initialize
      @transactions = []
      @provider_balances = Hash.new(0.0)
      @merchant_profit_total = 0.0
    end

    def record_transaction(operation_id:, provider_id:, amount:, provider_margin_pct:, merchant_margin_pct:, approved:)
      amt_d = PrecisionMath.to_d(amount)
      p_margin_d = PrecisionMath.to_d(provider_margin_pct)
      m_margin_d = PrecisionMath.to_d(merchant_margin_pct)

      provider_fee = (amt_d * (p_margin_d / 100)).round(4)
      merchant_revenue = (amt_d * (m_margin_d / 100)).round(4)
      net_margin = (merchant_revenue - provider_fee).round(4)

      record = {
        tx_id: "tx_#{@transactions.size + 1}",
        timestamp: Time.now.utc.iso8601,
        operation_id: operation_id,
        provider_id: provider_id,
        amount: amt_d.to_f,
        approved: approved,
        provider_fee: approved ? provider_fee.to_f : 0.0,
        merchant_revenue: approved ? merchant_revenue.to_f : 0.0,
        net_profit: approved ? net_margin.to_f : 0.0
      }

      @transactions << record

      if approved
        @provider_balances[provider_id] = (@provider_balances[provider_id] + amt_d.to_f).round(2)
        @merchant_profit_total = (@merchant_profit_total + net_margin.to_f).round(2)
      end

      record
    end

    def summary
      {
        total_transactions: @transactions.size,
        total_approved_volume: @provider_balances.values.sum.round(2),
        merchant_net_profit: @merchant_profit_total,
        provider_turnovers: @provider_balances.dup
      }
    end
  end
end
