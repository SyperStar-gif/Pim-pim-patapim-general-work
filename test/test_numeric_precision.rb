# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

class NumericPrecisionTestSuite
  def initialize
    @passed = 0
    @failed = 0
    @test_num = 0
  end

  def run
    puts "============================================================"
    puts "   NUMERIC & CRYPTO PRECISION TEST SUITE (20 CHECKS)        "
    puts "============================================================"

    # Test 1: Micro-amount 0.0001 float
    test("Micro-amount 0.0001 float is valid and accepted within boundaries") do
      p = build_provider(limit_amount_min: 0.00005, limit_amount_max: 0.001)
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_crypto_1', 'amount' => 0.0001, 'bank' => 'sber' })
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      op.valid? && eligible
    end

    # Test 2: Micro-amount 0.0001 passed as string
    test("Micro-amount '0.0001' string is parsed accurately") do
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_crypto_2', 'amount' => '0.0001', 'bank' => 'sber' })
      op.amount == 0.0001 && op.valid?
    end

    # Test 3: Scientific notation '1e-4'
    test("Scientific notation '1e-4' is parsed correctly into 0.0001") do
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_crypto_3', 'amount' => '1e-4', 'bank' => 'sber' })
      (op.amount - 0.0001).abs < 1e-9 && op.valid?
    end

    # Test 4: Satoshi precision 0.00000001 (8 decimal places)
    test("Satoshi 8-decimal precision 0.00000001 is preserved") do
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_sat', 'amount' => '0.00000001', 'bank' => 'sber' })
      op.amount == 0.00000001 && op.valid?
    end

    # Test 5: IEEE 754 float subtraction edge case: 0.0003 - 0.0002 vs min 0.0001
    test("IEEE 754 precision glitch (0.0003 - 0.0002) is NOT falsely rejected by limit_amount_min 0.0001") do
      p = build_provider(limit_amount_min: 0.0001, limit_amount_max: 10)
      # In raw ruby: (0.0003 - 0.0002) < 0.0001 is true!
      amt = 0.0003 - 0.0002
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_edge', 'amount' => amt, 'bank' => 'sber' })
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 6: IEEE 754 float addition edge case: 0.1 + 0.2 vs max 0.3
    test("IEEE 754 precision glitch (0.1 + 0.2) is NOT falsely rejected by limit_amount_max 0.3") do
      p = build_provider(limit_amount_min: 0.01, limit_amount_max: 0.3)
      # In raw ruby: (0.1 + 0.2) > 0.3 is true!
      amt = 0.1 + 0.2
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_max_edge', 'amount' => amt, 'bank' => 'sber' })
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 7: Daily limit exact float boundary (0.1 + 0.2 == 0.3)
    test("Daily limit exact float boundary (0.1 + 0.2 <= 0.3) passes without false rejection") do
      p = build_provider(
        limit_amount_min: 0.01,
        limit_amount_max: 1.0,
        daily_amount_limit: 0.3,
        daily_approved_amount: 0.1
      )
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_daily_float', 'amount' => 0.2, 'bank' => 'sber' })
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 8: In-progress amount exact float boundary
    test("In-progress amount exact float boundary (0.1 + 0.2 <= 0.3) passes") do
      p = build_provider(
        limit_amount_min: 0.01,
        limit_amount_max: 1.0,
        in_progress_amount_limit: 0.3,
        in_progress_amount: 0.1
      )
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_inp_float', 'amount' => 0.2, 'bank' => 'sber' })
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 9: Zero amount rejected
    test("Zero amount (0.0) is rejected as invalid/below minimum") do
      p = build_provider(limit_amount_min: 0)
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_zero', 'amount' => 0, 'bank' => 'sber' })
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !op.valid? || (!eligible && %w[invalid_amount amount_below_min].include?(reason))
    end

    # Test 10: Negative amount rejected
    test("Negative amount (-50) is rejected as invalid") do
      p = build_provider(limit_amount_min: 0)
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_neg', 'amount' => -50, 'bank' => 'sber' })
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !op.valid? || (!eligible && reason == 'invalid_amount')
    end

    # Test 11: String amount with padding
    test("Amount with whitespace string '  25000.50  ' is cleanly parsed") do
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_pad', 'amount' => '  25000.50  ', 'bank' => 'sber' })
      op.amount == 25000.5 && op.valid?
    end

    # Test 12: Zero division guard in daily_utilization_pct (limit = 0)
    test("daily_utilization_pct with daily_amount_limit=0 returns 0.0 without ZeroDivisionError") do
      p = build_provider(daily_amount_limit: 0, daily_approved_amount: 5000)
      p.daily_utilization_pct == 0.0
    end

    # Test 13: Zero division guard with infinite daily limit
    test("daily_utilization_pct with daily_amount_limit=Float::INFINITY returns 0.0") do
      p = build_provider(daily_amount_limit: Float::INFINITY, daily_approved_amount: 5000)
      p.daily_utilization_pct == 0.0
    end

    # Test 14: Zero division guard in rate_limit_intensity (RPM limit = 0)
    test("Scoring rate_limit_intensity with requests_per_minute_limit=0 avoids ZeroDivisionError") do
      p = build_provider(requests_per_minute_limit: 0)
      engine = SmartRouter::ScoringEngine.new
      res = engine.score_provider(p, build_operation, {}, 'rate_limit_intensity')
      res[:score].is_a?(Numeric)
    end

    # Test 15: Zero division guard in traffic_share (total_routed = 0)
    test("Scoring traffic_share with total_routed=0 avoids ZeroDivisionError") do
      p = build_provider(traffic_percentage: 30)
      engine = SmartRouter::ScoringEngine.new
      res = engine.score_provider(p, build_operation, { total_operations_routed: 0 }, 'traffic_share')
      res[:score] == 80.0
    end

    # Test 16: Zero division guard in volume_share (total_volume = 0)
    test("Scoring volume_share with total_volume_routed=0 avoids ZeroDivisionError") do
      p = build_provider(volume_share_pct: 25)
      engine = SmartRouter::ScoringEngine.new
      res = engine.score_provider(p, build_operation, { total_volume_routed: 0.0 }, 'volume_share')
      res[:score] == 75.0
    end

    # Test 17: Float drift stability over 1,000 micro-transactions
    test("1,000 micro-transactions of 0.0001 preserve exact 0.1 sum without drift") do
      p = build_provider
      1000.times do
        p.reserve_in_progress!(0.0001)
        p.release_in_progress!(0.0001, approved: true)
      end
      # Exactly 0.1 without 0.10000000000000028
      (p.daily_approved_amount - 0.1).abs < 1e-9 && p.in_progress_amount == 0.0
    end

    # Test 18: Float margin comparison: 0.1 + 0.2 vs 0.3
    test("Float margin comparison (0.1 + 0.2 <= 0.3) is recognized as profitable") do
      # 0.1 + 0.2 > 0.3 in raw float!
      p = build_provider(
        provider_margin_pct: 0.1 + 0.2,
        merchant_margin_pct: 0.3,
        allow_negative_agreement: false
      )
      p.margin_profitable?
    end

    # Test 19: AnalyticsReporter preserves micro-amounts
    test("AnalyticsReporter preserves decimal amounts without truncating to zero") do
      p = build_provider(id: 'cryptopay', daily_amount_limit: 1.5, daily_approved_amount: 0.0001)
      rep = SmartRouter::AnalyticsReporter.generate_report([], { 'cryptopay' => p })
      used = rep['projected_daily_utilization']['cryptopay']['used']
      used == 0.0001
    end

    # Test 20: HardConstraints details string displays 0.0001 instead of 0
    test("HardConstraints details string formats 0.0001 as '0.0001' not '0'") do
      p = build_provider(limit_amount_min: 0.001)
      op = SmartRouter::Operation.new({ 'operation_id' => 'op_fmt', 'amount' => 0.0001, 'bank' => 'sber' })
      _, _, details = SmartRouter::HardConstraints.check(p, op)
      details.include?('0.0001 < limit_amount_min 0.001')
    end

    puts "\n" + "=" * 60
    puts "NUMERIC SUITE SUMMARY: #{@passed} PASSED, #{@failed} FAILED (TOTAL #{@test_num})"
    puts "=" * 60

    exit(@failed.zero? ? 0 : 1)
  end

  private

  def test(name)
    @test_num += 1
    result = begin
      yield
    rescue => e
      puts "  [FAIL] Test #{sprintf('%2d', @test_num)}: #{name}"
      puts "         Exception: #{e.class} - #{e.message}"
      puts "         #{e.backtrace.first(3).join("\n         ")}"
      false
    end

    if result
      @passed += 1
      puts "  [PASS] Test #{sprintf('%2d', @test_num)}: #{name}"
    else
      @failed += 1
      puts "  [FAIL] Test #{sprintf('%2d', @test_num)}: #{name}" unless result.nil?
    end
  end

  def build_provider(overrides = {})
    data = {
      'name' => overrides[:name] || 'TestProvider',
      'status' => overrides[:status] || 'active',
      'traffic_percentage' => overrides[:traffic_percentage] || 30.0,
      'volume_share_pct' => overrides[:volume_share_pct] || 30.0,
      'priority' => overrides[:priority] || 1,
      'limit_amount_min' => overrides[:limit_amount_min] || 1000,
      'limit_amount_max' => overrides[:limit_amount_max] || 100_000,
      'daily_amount_limit' => overrides[:daily_amount_limit] || 5_000_000,
      'daily_approved_amount' => overrides[:daily_approved_amount] || 0,
      'in_progress_count_limit' => overrides[:in_progress_count_limit] || 50,
      'in_progress_count' => overrides[:in_progress_count] || 0,
      'in_progress_amount_limit' => overrides[:in_progress_amount_limit] || 500_000,
      'in_progress_amount' => overrides[:in_progress_amount] || 0,
      'available_requisites' => overrides[:available_requisites] || 10,
      'banks' => overrides[:banks] || %w[sber tbank],
      'exclude_banks' => overrides[:exclude_banks] || [],
      'conversion_24h' => overrides[:conversion_24h] || 0.95,
      'provider_margin_pct' => overrides[:provider_margin_pct] || 2.0,
      'merchant_margin_pct' => overrides[:merchant_margin_pct] || 2.8,
      'requests_per_minute_limit' => overrides[:requests_per_minute_limit] || 30,
      'current_requests_this_minute' => overrides[:current_requests_this_minute] || 0,
      'daily_turnover_min' => overrides[:daily_turnover_min] || 0,
      'daily_turnover_max' => overrides[:daily_turnover_max] || 5_000_000,
      'allow_negative_agreement' => overrides[:allow_negative_agreement] || false,
      'avg_latency_sec' => overrides[:avg_latency_sec] || 15,
      'is_fallback' => overrides[:is_fallback] || false
    }
    p_id = overrides[:id] || 'test_provider'
    SmartRouter::Provider.new(p_id, data)
  end

  def build_operation(overrides = {})
    SmartRouter::Operation.new({
      'operation_id' => overrides[:operation_id] || 'op_test_1',
      'amount' => overrides[:amount] || 25_000,
      'bank' => overrides[:bank] || 'sber',
      'client_id' => overrides[:client_id] || 'usr_1',
      'created_at' => '2026-03-30T10:00:00Z'
    })
  end
end

if __FILE__ == $PROGRAM_NAME
  NumericPrecisionTestSuite.new.run
end
