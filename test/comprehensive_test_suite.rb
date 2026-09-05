# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

class ComprehensiveTestSuite
  def initialize
    @passed = 0
    @failed = 0
    @test_num = 0
  end

  def run
    puts "============================================================"
    puts "      SMART PAYMENT ROUTER — 40 TEST COMPREHENSIVE SUITE    "
    puts "============================================================"

    # --- GROUP 1: HARD CONSTRAINTS (Tests 1 - 18) ---
    puts "\n--- [GROUP 1] HARD CONSTRAINTS VALIDATION ---"

    # Test 1: Inactive provider
    test("Provider inactive status is rejected with 'provider_inactive'") do
      p = build_provider(status: 'inactive')
      op = build_operation
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'provider_inactive'
    end

    # Test 2: Maintenance provider
    test("Provider maintenance status is rejected with 'provider_inactive'") do
      p = build_provider(status: 'maintenance')
      op = build_operation
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'provider_inactive'
    end

    # Test 3: Amount below limit_amount_min
    test("Amount below min threshold is rejected with 'amount_below_min'") do
      p = build_provider(limit_amount_min: 5000)
      op = build_operation(amount: 4999)
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'amount_below_min'
    end

    # Test 4: Amount equals limit_amount_min (Boundary)
    test("Amount equal to min threshold is eligible (boundary pass)") do
      p = build_provider(limit_amount_min: 5000)
      op = build_operation(amount: 5000)
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 5: Amount equals limit_amount_max (Boundary)
    test("Amount equal to max threshold is eligible (boundary pass)") do
      p = build_provider(limit_amount_max: 100_000)
      op = build_operation(amount: 100_000)
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 6: Amount exceeds limit_amount_max
    test("Amount exceeding max threshold is rejected with 'amount_exceeds_limit'") do
      p = build_provider(limit_amount_max: 100_000)
      op = build_operation(amount: 100_001)
      eligible, reason, details = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'amount_exceeds_limit' && details.include?('100001 > limit_amount_max 100000')
    end

    # Test 7: Daily approved limit exceeded
    test("Daily limit exceeded is rejected with 'daily_limit_exceeded'") do
      p = build_provider(daily_amount_limit: 5_000_000, daily_approved_amount: 4_950_000)
      op = build_operation(amount: 60_000)
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'daily_limit_exceeded'
    end

    # Test 8: Daily approved limit exact boundary
    test("Daily limit exact boundary is eligible (4.95m + 50k = 5.0m)") do
      p = build_provider(daily_amount_limit: 5_000_000, daily_approved_amount: 4_950_000)
      op = build_operation(amount: 50_000)
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 9: In-progress count limit reached
    test("In-progress count limit reached is rejected with 'in_progress_count_limit_reached'") do
      p = build_provider(in_progress_count_limit: 10, in_progress_count: 10)
      op = build_operation
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'in_progress_count_limit_reached'
    end

    # Test 10: In-progress count below limit
    test("In-progress count below limit is eligible") do
      p = build_provider(in_progress_count_limit: 10, in_progress_count: 9)
      op = build_operation
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 11: In-progress amount limit reached
    test("In-progress amount limit exceeded is rejected with 'in_progress_amount_limit_reached'") do
      p = build_provider(in_progress_amount_limit: 1_000_000, in_progress_amount: 980_000)
      op = build_operation(amount: 30_000)
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'in_progress_amount_limit_reached'
    end

    # Test 12: In-progress amount below limit
    test("In-progress amount below limit is eligible") do
      p = build_provider(in_progress_amount_limit: 1_000_000, in_progress_amount: 950_000)
      op = build_operation(amount: 50_000)
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 13: Available requisites is 0
    test("Zero available requisites is rejected with 'no_available_requisites'") do
      p = build_provider(available_requisites: 0)
      op = build_operation
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'no_available_requisites'
    end

    # Test 14: Available requisites > 0
    test("Positive available requisites is eligible") do
      p = build_provider(available_requisites: 5)
      op = build_operation
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 15: Bank in exclude_banks list
    test("Bank in exclude_banks blacklist is rejected with 'bank_excluded'") do
      p = build_provider(exclude_banks: ['gazprombank', 'raiffeisen'])
      op = build_operation(bank: 'gazprombank')
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'bank_excluded'
    end

    # Test 16: Bank not in allowed banks list
    test("Bank not in supported whitelist is rejected with 'bank_not_in_list'") do
      p = build_provider(banks: ['sber', 'tbank'])
      op = build_operation(bank: 'vtb')
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'bank_not_in_list'
    end

    # Test 17: Bank in allowed banks list
    test("Bank in supported whitelist is eligible") do
      p = build_provider(banks: ['sber', 'tbank'])
      op = build_operation(bank: 'sber')
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 18: Empty allowed banks list supports all non-excluded banks
    test("Empty bank whitelist supports any non-excluded bank") do
      p = build_provider(banks: [], exclude_banks: ['ozon'])
      op = build_operation(bank: 'alfa')
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # --- GROUP 2: MARGIN & RATE LIMITING (Tests 19 - 23) ---
    puts "\n--- [GROUP 2] MARGIN & RATE LIMITING ---"

    # Test 19: Unprofitable margin without agreement
    test("Unprofitable margin (3.5% > 2.0%) rejected with 'margin_agreement_negative'") do
      p = build_provider(provider_margin_pct: 3.5, merchant_margin_pct: 2.0, allow_negative_agreement: false)
      op = build_operation
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'margin_agreement_negative'
    end

    # Test 20: Unprofitable margin WITH agreement
    test("Unprofitable margin WITH allow_negative_agreement=true is eligible") do
      p = build_provider(provider_margin_pct: 3.5, merchant_margin_pct: 2.0, allow_negative_agreement: true)
      op = build_operation
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 21: Profitable margin
    test("Profitable margin (1.8% <= 2.8%) is eligible") do
      p = build_provider(provider_margin_pct: 1.8, merchant_margin_pct: 2.8)
      op = build_operation
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # Test 22: Rate limit exceeded (RPM)
    test("Requests per minute limit exceeded is rejected with 'rate_limit_exceeded'") do
      p = build_provider(requests_per_minute_limit: 20, current_requests_this_minute: 20)
      op = build_operation
      eligible, reason, _ = SmartRouter::HardConstraints.check(p, op)
      !eligible && reason == 'rate_limit_exceeded'
    end

    # Test 23: Rate limit within quota
    test("Requests per minute within quota is eligible") do
      p = build_provider(requests_per_minute_limit: 20, current_requests_this_minute: 15)
      op = build_operation
      eligible, _, _ = SmartRouter::HardConstraints.check(p, op)
      eligible
    end

    # --- GROUP 3: SOFT-GOALS & STRATEGIES (Tests 24 - 32) ---
    puts "\n--- [GROUP 3] SOFT-GOALS & STRATEGIES ---"
    engine = SmartRouter::ScoringEngine.new

    # Test 24: traffic_share strategy
    test("Strategy 'traffic_share' scores provider with deficit higher") do
      p_behind = build_provider(id: 'behind', traffic_percentage: 40)
      p_behind.processed_count = 1
      p_ahead = build_provider(id: 'ahead', traffic_percentage: 40)
      p_ahead.processed_count = 9
      ctx = { total_operations_routed: 10 }
      score1 = engine.score_provider(p_behind, build_operation, ctx, 'traffic_share')[:score]
      score2 = engine.score_provider(p_ahead, build_operation, ctx, 'traffic_share')[:score]
      score1 > score2
    end

    # Test 25: volume_share strategy
    test("Strategy 'volume_share' scores provider with volume deficit higher") do
      p1 = build_provider(id: 'p1', volume_share_pct: 50)
      p1.processed_volume = 100_000
      p2 = build_provider(id: 'p2', volume_share_pct: 50)
      p2.processed_volume = 900_000
      ctx = { total_volume_routed: 1_000_000 }
      score1 = engine.score_provider(p1, build_operation, ctx, 'volume_share')[:score]
      score2 = engine.score_provider(p2, build_operation, ctx, 'volume_share')[:score]
      score1 > score2
    end

    # Test 26: cascade_priority strategy
    test("Strategy 'cascade_priority' orders strictly by priority rank (1 > 2 > 3)") do
      p_top = build_provider(priority: 1)
      p_mid = build_provider(priority: 2)
      score_top = engine.score_provider(p_top, build_operation, {}, 'cascade_priority')[:score]
      score_mid = engine.score_provider(p_mid, build_operation, {}, 'cascade_priority')[:score]
      score_top > score_mid
    end

    # Test 27: amount_tier strategy (<50k -> payflow)
    test("Strategy 'amount_tier' favors payflow for amount <= 50,000") do
      p_payflow = build_provider(id: 'payflow')
      p_vipay = build_provider(id: 'vipay')
      op_small = build_operation(amount: 25_000)
      s_payflow = engine.score_provider(p_payflow, op_small, {}, 'amount_tier')[:score]
      s_vipay = engine.score_provider(p_vipay, op_small, {}, 'amount_tier')[:score]
      s_payflow > s_vipay
    end

    # Test 28: amount_tier strategy (50k-100k -> vipay)
    test("Strategy 'amount_tier' favors vipay for amount 50,001 - 100,000") do
      p_vipay = build_provider(id: 'vipay')
      p_quickpay = build_provider(id: 'quickpay')
      op_mid = build_operation(amount: 75_000)
      s_vipay = engine.score_provider(p_vipay, op_mid, {}, 'amount_tier')[:score]
      s_quickpay = engine.score_provider(p_quickpay, op_mid, {}, 'amount_tier')[:score]
      s_vipay > s_quickpay
    end

    # Test 29: amount_tier strategy (>100k -> quickpay)
    test("Strategy 'amount_tier' favors quickpay for amount > 100,000") do
      p_quickpay = build_provider(id: 'quickpay')
      p_space = build_provider(id: 'spacepayments')
      op_large = build_operation(amount: 200_000)
      s_quickpay = engine.score_provider(p_quickpay, op_large, {}, 'amount_tier')[:score]
      s_space = engine.score_provider(p_space, op_large, {}, 'amount_tier')[:score]
      s_quickpay > s_space
    end

    # Test 30: conversion_boost strategy
    test("Strategy 'conversion_boost' ranks higher conversion provider above lower") do
      p_high = build_provider(conversion_24h: 0.96)
      p_low = build_provider(conversion_24h: 0.89)
      s_high = engine.score_provider(p_high, build_operation, {}, 'conversion_boost')[:score]
      s_low = engine.score_provider(p_low, build_operation, {}, 'conversion_boost')[:score]
      s_high > s_low
    end

    # Test 31: rate_limit_intensity strategy
    test("Strategy 'rate_limit_intensity' favors provider with more RPM headroom") do
      p_free = build_provider(requests_per_minute_limit: 30, current_requests_this_minute: 5)
      p_busy = build_provider(requests_per_minute_limit: 30, current_requests_this_minute: 25)
      s_free = engine.score_provider(p_free, build_operation, {}, 'rate_limit_intensity')[:score]
      s_busy = engine.score_provider(p_busy, build_operation, {}, 'rate_limit_intensity')[:score]
      s_free > s_busy
    end

    # Test 32: financial_obligations strategy
    test("Strategy 'financial_obligations' boosts provider with unfulfilled minimum turnover") do
      p_deficit = build_provider(daily_turnover_min: 2_000_000, daily_approved_amount: 500_000)
      p_done = build_provider(daily_turnover_min: 2_000_000, daily_approved_amount: 2_100_000)
      s_deficit = engine.score_provider(p_deficit, build_operation, {}, 'financial_obligations')[:score]
      s_done = engine.score_provider(p_done, build_operation, {}, 'financial_obligations')[:score]
      s_deficit > s_done
    end

    # --- GROUP 4: CASCADE ROUTING & FALLBACK (Tests 33 - 37) ---
    puts "\n--- [GROUP 4] CASCADE ROUTING & FALLBACK ---"

    # Test 33: Single eligible provider
    test("Single eligible provider selects it with reason 'only_eligible_provider'") do
      providers_hash = {
        'vipay' => { 'status' => 'active', 'limit_amount_max' => 100_000 },
        'payflow' => { 'status' => 'active', 'limit_amount_max' => 50_000 },
        'quickpay' => { 'status' => 'active', 'limit_amount_max' => 500_000 }
      }
      router = SmartRouter::Router.new(providers_hash, seed: 100)
      op = build_operation(amount: 150_000)
      dec = router.route_single_operation(op)
      dec['selected_provider'] == 'quickpay' && dec['attempts'].any? { |a| a['reason'] == 'only_eligible_provider' }
    end

    # Test 34: Multiple eligible candidates scored and ranked
    test("Multiple candidates sorted by strategy score") do
      providers_hash = {
        'vipay' => { 'status' => 'active', 'priority' => 1, 'limit_amount_max' => 100_000, 'conversion_24h' => 1.0 },
        'payflow' => { 'status' => 'active', 'priority' => 2, 'limit_amount_max' => 100_000, 'conversion_24h' => 1.0 }
      }
      router = SmartRouter::Router.new(providers_hash, strategy: 'cascade_priority', seed: 100)
      op = build_operation(amount: 30_000)
      dec = router.route_single_operation(op)
      dec['selected_provider'] == 'vipay'
    end

    # Test 35: Cascade fallback on provider refusal/timeout
    test("Primary provider refusal triggers cascade to next candidate") do
      providers_hash = {
        'shaky' => { 'status' => 'active', 'conversion_24h' => 0.0, 'priority' => 1, 'limit_amount_max' => 100_000 },
        'solid' => { 'status' => 'active', 'conversion_24h' => 1.0, 'priority' => 2, 'limit_amount_max' => 100_000 }
      }
      router = SmartRouter::Router.new(providers_hash, strategy: 'cascade_priority', seed: 42)
      op = build_operation(amount: 10_000)
      dec = router.route_single_operation(op)
      # shaky must have been skipped due to decline, solid selected
      shaky_att = dec['attempts'].find { |a| a['provider'] == 'shaky' }
      shaky_att['decision'] == 'skipped' && dec['selected_provider'] == 'solid'
    end

    # Test 36: All candidates fail -> SpacePayments fallback
    test("All external providers failing triggers fallback to spacepayments") do
      providers_hash = {
        'fail1' => { 'status' => 'active', 'conversion_24h' => 0.0, 'limit_amount_max' => 100_000 },
        'fail2' => { 'status' => 'active', 'conversion_24h' => 0.0, 'limit_amount_max' => 100_000 }
      }
      router = SmartRouter::Router.new(providers_hash, seed: 42)
      op = build_operation(amount: 10_000)
      dec = router.route_single_operation(op)
      dec['selected_provider'] == 'spacepayments'
    end

    # Test 37: Hard-constraints eliminate all external -> direct fallback
    test("Hard-constraints eliminating all external triggers direct fallback") do
      providers_hash = {
        'small1' => { 'status' => 'active', 'limit_amount_max' => 10_000 },
        'small2' => { 'status' => 'active', 'limit_amount_max' => 20_000 }
      }
      router = SmartRouter::Router.new(providers_hash)
      op = build_operation(amount: 500_000)
      dec = router.route_single_operation(op)
      dec['selected_provider'] == 'spacepayments'
    end

    # --- GROUP 5: STATE MUTATION & ANALYTICS (Tests 38 - 40) ---
    puts "\n--- [GROUP 5] STATE MUTATION & ANALYTICS ---"

    # Test 38: Approval increments metrics
    test("Approval correctly updates provider daily_approved_amount and processed_volume") do
      p = build_provider(daily_approved_amount: 100_000)
      p.reserve_in_progress!(25_000)
      p.release_in_progress!(25_000, approved: true)
      p.daily_approved_amount == 125_000 && p.processed_volume == 25_000 && p.successful_count == 1
    end

    # Test 39: Rejection does not increment daily_approved_amount
    test("Rejection does not increment provider daily_approved_amount") do
      p = build_provider(daily_approved_amount: 100_000)
      p.reserve_in_progress!(25_000)
      p.release_in_progress!(25_000, approved: false)
      p.daily_approved_amount == 100_000 && p.failed_count == 1
    end

    # Test 40: Analytics report generator produces accurate summary & recommendations
    test("AnalyticsReporter generates valid distribution, skip_reasons and recommendations") do
      providers_data = JSON.parse(File.read('data/providers.json'))
      router = SmartRouter::Router.new(providers_data)
      queue = JSON.parse(File.read('data/operations_queue.json'))
      decisions = router.route_queue(queue)
      report = SmartRouter::AnalyticsReporter.generate_report(decisions, router.providers)
      report['total_operations'] == queue.size &&
        report['distribution'].key?('vipay') &&
        report['skip_reasons'].is_a?(Hash) &&
        report['recommendations'].any?
    end

    puts "\n============================================================"
    puts "SUITE SUMMARY: #{@passed} PASSED, #{@failed} FAILED (TOTAL #{@test_num})"
    puts "============================================================"
    exit(@failed == 0 ? 0 : 1)
  end

  private

  def test(description)
    @test_num += 1
    result = yield
    if result
      @passed += 1
      puts "  [PASS] Test #{@test_num.to_s.rjust(2)}: #{description}"
    else
      @failed += 1
      puts "  [FAIL] Test #{@test_num.to_s.rjust(2)}: #{description}"
    end
  rescue StandardError => e
    @failed += 1
    puts "  [ERROR] Test #{@test_num.to_s.rjust(2)}: #{description} (#{e.message})"
  end

  def build_provider(id: 'test_provider', **attrs)
    defaults = {
      'name' => id.to_s.capitalize,
      'status' => 'active',
      'traffic_percentage' => 40,
      'volume_share_pct' => 40,
      'priority' => 1,
      'limit_amount_min' => 1000,
      'limit_amount_max' => 100_000,
      'daily_amount_limit' => 5_000_000,
      'daily_approved_amount' => 0,
      'in_progress_count_limit' => 50,
      'in_progress_count' => 0,
      'in_progress_amount_limit' => 5_000_000,
      'in_progress_amount' => 0,
      'available_requisites' => 10,
      'banks' => [],
      'exclude_banks' => [],
      'conversion_24h' => 0.95,
      'provider_margin_pct' => 2.0,
      'merchant_margin_pct' => 2.8,
      'requests_per_minute_limit' => 30,
      'current_requests_this_minute' => 0,
      'daily_turnover_min' => 0,
      'allow_negative_agreement' => false
    }
    attrs_string_keys = {}
    attrs.each { |k, v| attrs_string_keys[k.to_s] = v }
    SmartRouter::Provider.new(id, defaults.merge(attrs_string_keys))
  end

  def build_operation(id: 'op_test', amount: 10_000, bank: 'sber', client_id: 'usr_1')
    SmartRouter::Operation.new({
      'operation_id' => id,
      'amount' => amount,
      'bank' => bank,
      'client_id' => client_id
    })
  end
end

ComprehensiveTestSuite.new.run
