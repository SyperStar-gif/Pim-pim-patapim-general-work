# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

module SmartRouter
  # TestPolicyAndResilience verifies MachineReadableReporter, MultiCurrencyRouter,
  # RoutingPolicyConfig, and GatewayCircuitBreaker.
  class TestPolicyAndResilience
    def self.run
      puts '=' * 60
      puts '  RESILIENCE & POLICY ENGINE TEST SUITE (25 CHECKS)'
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

      # --- 1. Gateway Circuit Breaker Tests ---
      cb = GatewayCircuitBreaker.new(failure_threshold: 3, recovery_timeout_sec: 1)
      assert.call('Circuit breaker initially closed', cb.allow_request?('vipay'))

      cb.record_failure('vipay')
      assert.call('Circuit breaker remains closed after 1 failure', cb.allow_request?('vipay'))
      cb.record_failure('vipay')
      cb.record_failure('vipay')
      assert.call('Circuit breaker trips OPEN after 3 failures', !cb.allow_request?('vipay'))

      # Wait for recovery timeout
      sleep 1.1
      assert.call('Circuit breaker transitions to half-open after timeout', cb.allow_request?('vipay'))
      cb.record_success('vipay')
      assert.call('Circuit breaker resets to CLOSED on success', cb.allow_request?('vipay'))

      # --- 2. Multi Currency Router Tests ---
      mc = MultiCurrencyRouter.new
      rub_from_usd = mc.convert_to_rub(100, 'USD')
      assert.call('MultiCurrency converts 100 USD to 9250 RUB', rub_from_usd == 9250.0)

      usd_from_rub = mc.convert_from_rub(9250, 'USD')
      assert.call('MultiCurrency converts 9250 RUB to 100 USD', (usd_from_rub - 100.0).abs < 0.01)

      norm_op = mc.normalize_operation({ 'operation_id' => 'op_usd', 'amount' => 50, 'currency' => 'USD', 'bank' => 'sber' })
      assert.call('MultiCurrency normalizes operation to RUB', norm_op['amount'] == 4625.0 && norm_op['currency'] == 'RUB')
      assert.call('MultiCurrency preserves original amount and currency', norm_op['original_amount'] == 50.0 && norm_op['original_currency'] == 'USD')

      # Custom rate update
      mc.update_rate('EUR', 110.0)
      assert.call('MultiCurrency accepts updated exchange rate', mc.convert_to_rub(10, 'EUR') == 1100.0)

      # --- 3. Routing Policy Config Tests ---
      cfg = RoutingPolicyConfig.new
      assert.call('RoutingPolicyConfig has default strategy combined', cfg.strategy == 'combined')
      assert.call('RoutingPolicyConfig has default weights', cfg.weights[:traffic_share] == 0.25)

      cfg.merge!({ 'strategy' => 'cascade_priority', 'weights' => { 'priority' => 0.8 } })
      assert.call('RoutingPolicyConfig updates strategy to cascade_priority', cfg.strategy == 'cascade_priority')
      assert.call('RoutingPolicyConfig deep merges weights', cfg.weights[:priority] == 0.8 && cfg.weights[:traffic_share] == 0.25)

      # --- 4. Machine Readable Reporter Tests ---
      sample_decisions = [
        {
          'operation_id' => 'op_1',
          'selected_provider' => 'vipay',
          'attempts' => [
            { 'provider' => 'payflow', 'decision' => 'skipped', 'reason' => 'amount_exceeds_limit' },
            { 'provider' => 'vipay', 'decision' => 'selected', 'reason' => 'best_score' }
          ],
          'simulated_result' => 'approved',
          'latency_sec' => 20
        },
        {
          'operation_id' => 'op_2',
          'selected_provider' => 'spacepayments',
          'attempts' => [
            { 'provider' => 'vipay', 'decision' => 'skipped', 'reason' => 'daily_limit_exceeded' },
            { 'provider' => 'spacepayments', 'decision' => 'selected', 'reason' => 'fallback' }
          ],
          'simulated_result' => 'approved',
          'latency_sec' => 10
        }
      ]

      mr = MachineReadableReporter.new(sample_decisions, {
        'distribution' => { 'vipay' => { 'count' => 1 }, 'spacepayments' => { 'count' => 1 } }
      })
      diag = mr.generate_extended_diagnostics
      assert.call('MachineReadableReporter computes summary total ops', diag[:summary][:total_operations] == 2)
      assert.call('MachineReadableReporter calculates 100% approval rate', diag[:summary][:approval_rate_pct] == 100.0)
      assert.call('MachineReadableReporter calculates average latency 15 sec', diag[:summary][:avg_latency_sec] == 15.0)
      assert.call('MachineReadableReporter aggregates skip reasons tally', diag[:skip_reasons]['amount_exceeds_limit'] == 1)
      assert.call('MachineReadableReporter aggregates selection reasons tally', diag[:selection_reasons]['best_score'] == 1)
      assert.call('MachineReadableReporter measures avg cascade depth', diag[:summary][:avg_cascade_depth] == 2.0)

      puts '-' * 60
      puts "RESILIENCE SUITE: #{passed} PASSED, #{failed} FAILED (TOTAL #{passed + failed})"
      puts '=' * 60
      failed.zero?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  success = SmartRouter::TestPolicyAndResilience.run
  exit(success ? 0 : 1)
end
