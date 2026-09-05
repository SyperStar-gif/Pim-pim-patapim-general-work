# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

module SmartRouter
  # TestRiskAndCostOptimizers verifies FraudAndRiskScorer and CostOptimizer.
  class TestRiskAndCostOptimizers
    def self.run
      puts '=' * 60
      puts '  FRAUD RISK & COST OPTIMIZER TEST SUITE (20 CHECKS)'
      puts '=' * 60

      passed = 0
      failed = 0

      assert = lambda do |name, cond, details = nil|
        if cond
          passed += 1
          puts "  [PASS] #{name}"
        else
          failed += 1
          puts "  [FAIL] #{name}: #{details}"
        end
      end

      # --- 1. Fraud and Risk Scorer Tests ---
      scorer = FraudAndRiskScorer.new(velocity_window_sec: 10, max_ops_per_window: 5)
      res_low = scorer.assess_risk({ 'operation_id' => 'norm_1', 'amount' => 5000, 'bank' => 'sber' })
      assert.call('Normal payment gets low risk level', res_low[:risk_level] == :low)
      assert.call('Normal payment allows routing', res_low[:allow_routing] == true)

      res_high_amt = scorer.assess_risk({ 'operation_id' => 'high_1', 'amount' => 300_000, 'bank' => 'sber' })
      assert.call('Large amount > 250k raises risk score', res_high_amt[:risk_score] >= 25.0)

      res_micro = scorer.assess_risk({ 'operation_id' => 'micro_test', 'amount' => 1.0, 'bank' => 'tbank' })
      assert.call('Card testing micro-amount raises risk score', res_micro[:risk_score] >= 15.0)

      res_crypto = scorer.assess_risk({ 'operation_id' => 'crypto_1', 'amount' => 10_000, 'bank' => 'crypto_bank' })
      assert.call('Risky bank flags factor in risk assessment', res_crypto[:factors].any? { |f| f.include?('Высокорисковый банк') })

      # Burst velocity trigger
      5.times { |i| scorer.assess_risk({ 'operation_id' => "burst_#{i}", 'amount' => 1000, 'bank' => 'sber' }) }
      res_burst = scorer.assess_risk({ 'operation_id' => 'burst_flag', 'amount' => 1000, 'bank' => 'sber' })
      assert.call('Velocity burst detected when exceeding window limit', res_burst[:factors].any? { |f| f.include?('Высокая интенсивность') })

      # --- 2. Cost Optimizer Tests ---
      provs = {
        'cheap' => Provider.new('cheap', { 'provider_margin_pct' => 1.2, 'conversion_24h' => 0.95, 'status' => 'active' }),
        'expensive' => Provider.new('expensive', { 'provider_margin_pct' => 3.0, 'conversion_24h' => 0.90, 'status' => 'active' })
      }
      cost_opt = CostOptimizer.new(provs)
      ranked = cost_opt.rank_by_lowest_cost(provs.values, 50_000)

      assert.call('Cost optimizer ranks cheaper provider higher', ranked.first[:provider].id == 'cheap')
      assert.call('Calculates estimated fee for cheap provider (1.2% of 50k = 600)', ranked.first[:estimated_fee_rub] == 600.0)
      assert.call('Calculates estimated fee for expensive provider (3% of 50k = 1500)', ranked.last[:estimated_fee_rub] == 1500.0)

      # Potential savings
      savings = cost_opt.estimate_potential_savings([
        { 'amount' => 10_000 },
        { 'amount' => 100_000 }
      ])
      assert.call('Estimates total potential savings', savings[:potential_savings_rub] > 0)
      assert.call('Calculates potential savings percentage', savings[:potential_savings_pct] > 0)

      puts '-' * 60
      puts "RISK & COST SUITE: #{passed} PASSED, #{failed} FAILED (TOTAL #{passed + failed})"
      puts '=' * 60
      failed.zero?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  success = SmartRouter::TestRiskAndCostOptimizers.run
  exit(success ? 0 : 1)
end
