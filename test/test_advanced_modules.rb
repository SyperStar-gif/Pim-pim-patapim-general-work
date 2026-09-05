# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

module SmartRouter
  # TestAdvancedModules verifies the functionality of RuleEngine, AnomalyDetector,
  # LoadBalancer, FinancialLedger, and RequisiteOptimizer.
  class TestAdvancedModules
    def self.run
      puts '=' * 60
      puts '  ADVANCED RUBY MODULES TEST SUITE (25 CHECKS)'
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

      # --- 1. Rule Engine Tests ---
      engine = RuleEngine.new
      engine.add_rule(
        name: 'Exclude payflow for high amounts',
        condition_block: ->(op, _provs) { op['amount'] > 100_000 },
        action_block: ->(_op, provs) { provs.reject { |p| p.id == 'payflow' } },
        priority: 20
      )
      assert.call('RuleEngine adds rule', engine.rules.size == 1)

      p1 = Provider.new('payflow', { 'status' => 'active' })
      p2 = Provider.new('vipay', { 'status' => 'active' })
      filtered = engine.evaluate_pre_filters({ 'amount' => 150_000 }, [p1, p2])
      assert.call('RuleEngine filters out payflow for 150k', filtered.map(&:id) == ['vipay'])

      filtered_low = engine.evaluate_pre_filters({ 'amount' => 50_000 }, [p1, p2])
      assert.call('RuleEngine keeps both for 50k', filtered_low.map(&:id).sort == %w[payflow vipay])

      # --- 2. Anomaly Detector Tests ---
      detector = AnomalyDetector.new
      provs = {
        'vipay' => Provider.new('vipay', { 'traffic_percentage' => 40.0, 'status' => 'active', 'daily_amount_limit' => 100_000, 'daily_approved_amount' => 95_000 }),
        'payflow' => Provider.new('payflow', { 'traffic_percentage' => 35.0, 'status' => 'active' })
      }
      alerts = detector.inspect_routing_state(provs, 50, 500_000)
      near_limit_alert = alerts.find { |a| a[:type] == 'daily_limit_near_exhaustion' }
      assert.call('AnomalyDetector catches near daily limit', near_limit_alert != nil && near_limit_alert[:provider] == 'vipay')

      starvation_alert = alerts.find { |a| a[:type] == 'traffic_starvation' }
      assert.call('AnomalyDetector catches traffic starvation when 0 processed', starvation_alert != nil)

      # --- 3. Load Balancer Tests ---
      balancer = LoadBalancer.new(:weighted_deficit)
      provs_lb = {
        'vipay' => Provider.new('vipay', { 'traffic_percentage' => 40.0, 'status' => 'active' }),
        'payflow' => Provider.new('payflow', { 'traffic_percentage' => 60.0, 'status' => 'active' })
      }
      weights = balancer.calculate_weights(provs_lb, 10, 100_000)
      assert.call('LoadBalancer calculates normalized weights', (weights.values.sum - 1.0).abs < 0.01)
      assert.call('LoadBalancer allocates higher weight to payflow (60%)', weights['payflow'] > weights['vipay'])

      # --- 4. Financial Ledger Tests ---
      ledger = FinancialLedger.new
      tx = ledger.record_transaction(
        operation_id: 'op_fin_1',
        provider_id: 'vipay',
        amount: 10_000,
        provider_margin_pct: 1.8,
        merchant_margin_pct: 2.8,
        approved: true
      )
      assert.call('FinancialLedger records approved tx', tx[:approved] == true)
      assert.call('FinancialLedger calculates net profit (1% of 10k = 100)', tx[:net_profit] == 100.0)
      assert.call('FinancialLedger accumulates turnover', ledger.provider_balances['vipay'] == 10_000.0)
      assert.call('FinancialLedger accumulates net profit', ledger.merchant_profit_total == 100.0)

      # Test rejected tx does not increase balance
      ledger.record_transaction(
        operation_id: 'op_fin_2',
        provider_id: 'vipay',
        amount: 50_000,
        provider_margin_pct: 1.8,
        merchant_margin_pct: 2.8,
        approved: false
      )
      assert.call('Rejected tx does not affect provider balance', ledger.provider_balances['vipay'] == 10_000.0)

      # --- 5. Requisite Optimizer Tests ---
      req_opt = RequisiteOptimizer.new({ 'vipay' => 5, 'payflow' => 3 })
      acquired = req_opt.acquire_requisite('vipay', 'op_1')
      assert.call('Requisite acquired successfully', acquired == true)
      assert.call('Requisite utilization increases to 20%', req_opt.utilization_pct('vipay') == 20.0)

      released = req_opt.release_requisite('op_1')
      assert.call('Requisite released successfully', released == true)
      assert.call('Requisite utilization drops back to 0%', req_opt.utilization_pct('vipay') == 0.0)

      # --- 6. Historical Analyzer Tests ---
      hist = HistoricalAnalyzer.new
      assert.call('HistoricalAnalyzer loads operations_history.csv', hist.records.size == 100)
      summary = hist.providers_summary
      assert.call('HistoricalAnalyzer summarizes vipay', summary['vipay'] != nil)
      assert.call('HistoricalAnalyzer summarizes payflow', summary['payflow'] != nil)
      assert.call('HistoricalAnalyzer summarizes quickpay', summary['quickpay'] != nil)
      assert.call('HistoricalAnalyzer calculates conversion for quickpay', summary['quickpay'][:empirical_conversion_pct] > 0)
      tiers = hist.volume_tiers_breakdown
      assert.call('HistoricalAnalyzer breaks down volume tiers', tiers[:medium][:count] > 0)
      recs = hist.generate_calibration_recommendations({
        'vipay' => { 'conversion_24h' => 0.50, 'volume_share_pct' => 10.0 }
      })
      assert.call('HistoricalAnalyzer generates recommendations for discrepancy', recs.any?)

      # --- 7. Audit Logger Tests ---
      logger = AuditLogger.new
      logger.log_attempt(operation_id: 'op_test', provider: 'vipay', decision: 'selected', reason: 'best_score', score: 0.95)
      logger.log_attempt(operation_id: 'op_test_2', provider: 'payflow', decision: 'skipped', reason: 'bank_not_in_list')
      assert.call('AuditLogger records attempts', logger.logs.size == 2)
      exp = logger.export_summary
      assert.call('AuditLogger exports summary', exp[:total_selected] == 1 && exp[:total_skipped] == 1)

      puts '-' * 60
      puts "MODULES SUITE: #{passed} PASSED, #{failed} FAILED (TOTAL #{passed + failed})"
      puts '=' * 60
      failed.zero?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  success = SmartRouter::TestAdvancedModules.run
  exit(success ? 0 : 1)
end
