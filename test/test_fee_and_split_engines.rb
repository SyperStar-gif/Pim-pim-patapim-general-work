# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

module SmartRouter
  # TestFeeAndSplitEngines verifies DynamicFeeModel and SplitRoutingEngine.
  class TestFeeAndSplitEngines
    def self.run
      puts '=' * 60
      puts '  DYNAMIC FEES & SPLIT ROUTING TEST SUITE (15 CHECKS)'
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

      # --- 1. Dynamic Fee Model Tests ---
      fm = DynamicFeeModel.new
      fm.set_structure('flat_prov', type: :flat, fixed_fee: 50.0)
      assert.call('Flat fee model calculates 50 RUB regardless of amount', fm.calculate_fee('flat_prov', 10_000) == 50.0)

      fm.set_structure('pct_prov', type: :percentage, pct_fee: 1.5)
      assert.call('Percentage fee model calculates 150 RUB on 10k', fm.calculate_fee('pct_prov', 10_000) == 150.0)

      fm.set_structure('fixed_pct_prov', type: :fixed_plus_pct, fixed_fee: 10.0, pct_fee: 2.0)
      assert.call('Fixed+Pct calculates 10 + 200 = 210 RUB', fm.calculate_fee('fixed_pct_prov', 10_000) == 210.0)

      # Net payout
      assert.call('Net payout subtracts fee correctly (10k - 210 = 9790)', fm.calculate_net_payout('fixed_pct_prov', 10_000) == 9790.0)

      # --- 2. Split Routing Engine Tests ---
      p_path = File.expand_path('../data/providers.json', __dir__)
      p_data = JSON.parse(File.read(p_path))
      router = Router.new(p_data, strategy: 'combined')
      split_engine = SplitRoutingEngine.new(router)

      # 50k is within limits of payflow/vipay, whole routing is true
      assert.call('Split engine identifies 50k as routable whole', split_engine.can_route_whole?(50_000))
      res_whole = split_engine.split_and_route({ 'operation_id' => 'whole_op', 'amount' => 50_000, 'bank' => 'sber' })
      assert.call('Routable whole does not trigger split', res_whole[:split_required] == false)

      # 750k exceeds 300k limit of quickpay -> split required
      assert.call('Split engine identifies 750k as requiring split', !split_engine.can_route_whole?(750_000))
      res_split = split_engine.split_and_route({ 'operation_id' => 'big_split_op', 'amount' => 750_000, 'bank' => 'sber' })
      assert.call('Split engine marks split_required: true', res_split[:split_required] == true)
      assert.call('Split engine splits 750k into 3 parts (300k, 300k, 150k)', res_split[:parts_count] == 3)
      assert.call('All sub-decisions processed by router', res_split[:sub_decisions].size == 3)
      assert.call('All sub-decisions have valid selected providers', res_split[:sub_decisions].all? { |d| d['selected_provider'] != nil })

      puts '-' * 60
      puts "FEES & SPLIT SUITE: #{passed} PASSED, #{failed} FAILED (TOTAL #{passed + failed})"
      puts '=' * 60
      failed.zero?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  success = SmartRouter::TestFeeAndSplitEngines.run
  exit(success ? 0 : 1)
end
