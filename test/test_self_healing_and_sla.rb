# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

module SmartRouter
  # TestSelfHealingAndSla verifies SelfHealingEngine, DynamicSlaMonitor,
  # and ReplaySimulationHarness.
  class TestSelfHealingAndSla
    def self.run
      puts '=' * 60
      puts '  SELF-HEALING, SLA & REPLAY TEST SUITE (20 CHECKS)'
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

      # --- 1. Self Healing Engine Tests ---
      sh = SelfHealingEngine.new
      assert.call('Initial throttle factor is 1.0', sh.effective_multiplier('vipay') == 1.0)

      sh.record_outcome('vipay', false)
      assert.call('Throttle factor degrades on failure', sh.effective_multiplier('vipay') < 1.0)

      sh.record_outcome('vipay', true)
      assert.call('Throttle factor recovers on success', sh.effective_multiplier('vipay') > 0.75)

      # High latency penalty
      sh.record_outcome('vipay', true, 50.0)
      assert.call('Latency penalty applied when > 45s', sh.action_log.any? { |l| l[:message].include?('Latency penalty') })

      # Quarantine
      sh.quarantine!('payflow', 1, 'manual_test')
      assert.call('Quarantined provider has effective multiplier 0.0', sh.effective_multiplier('payflow') == 0.0)
      assert.call('Provider is currently quarantined', sh.quarantined?('payflow'))

      sleep 1.1
      assert.call('Quarantine auto-expires after duration', !sh.quarantined?('payflow'))

      # --- 2. Dynamic SLA Monitor Tests ---
      sla = DynamicSlaMonitor.new({
        target_conversion_pct: 80.0,
        target_latency_p90_sec: 25.0,
        target_latency_max_sec: 50.0,
        max_rejection_rate_pct: 20.0
      })

      5.times { sla.record_operation('vipay', 'approved', 15.0) }
      eval1 = sla.evaluate_compliance('vipay')
      assert.call('SLA compliant when all approved with low latency', eval1[:compliant] == true)
      assert.call('SLA compliance 100%', eval1[:compliance_pct] == 100.0)

      # Introduce breaches
      5.times { sla.record_operation('quickpay', 'rejected', 60.0) }
      eval2 = sla.evaluate_compliance('quickpay')
      assert.call('SLA detects breaches on poor conversion and high latency', eval2[:compliant] == false)
      assert.call('SLA identifies breach reasons', eval2[:breaches].any?)

      # --- 3. Replay Simulation Harness Tests ---
      p_path = File.expand_path('../data/providers.json', __dir__)
      q_path = File.expand_path('../data/operations_queue.json', __dir__)
      p_data = JSON.parse(File.read(p_path))
      q_data = JSON.parse(File.read(q_path))

      harness = ReplaySimulationHarness.new(p_data, q_data)
      harness.run_all_strategies(42)

      assert.call('Harness ran combined strategy', harness.results_by_strategy['combined'] != nil)
      assert.call('Harness ran traffic_share strategy', harness.results_by_strategy['traffic_share'] != nil)
      assert.call('Harness ran volume_share strategy', harness.results_by_strategy['volume_share'] != nil)
      assert.call('Harness ran cascade_priority strategy', harness.results_by_strategy['cascade_priority'] != nil)

      comparison = harness.compare_key_metrics
      assert.call('Harness produces comparison table for all 8 strategies', comparison.keys.size == 8)
      assert.call('Harness records approval rate in comparison', comparison['combined'][:approval_rate_pct] > 0)

      puts '-' * 60
      puts "SELF-HEALING & SLA SUITE: #{passed} PASSED, #{failed} FAILED (TOTAL #{passed + failed})"
      puts '=' * 60
      failed.zero?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  success = SmartRouter::TestSelfHealingAndSla.run
  exit(success ? 0 : 1)
end
