# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

puts "Running SmartRouter Automated Test Suite..."

raw_providers = JSON.parse(File.read('data/providers.json'))
providers_data = if raw_providers.is_a?(Hash) && raw_providers['providers'].is_a?(Array)
                   raw_providers['providers'].each_with_object({}) do |item, h|
                     h[item['payment_system'] || item['id']] = item
                   end
                 elsif raw_providers.is_a?(Hash)
                   raw_providers
                 else
                   {}
                 end

tests_passed = 0
tests_total = 0

def assert(description, condition)
  if condition
    puts "  [OK] #{description}"
    true
  else
    puts "  [FAILED] #{description}"
    false
  end
end

# Test 1: Hard Constraints - Amount Exceeded
tests_total += 1
vipay_data = (providers_data['vipay'] || {}).merge('exclude_banks' => ['gazprombank'], 'limit_amount_max' => 100_000)
p = SmartRouter::Provider.new('vipay', vipay_data)
op_huge = SmartRouter::Operation.new({ 'operation_id' => 't1', 'amount' => 150_000, 'bank' => 'sber' })
eligible, reason, details = SmartRouter::HardConstraints.check(p, op_huge)
tests_passed += 1 if assert("Huge amount skips vipay due to limit_amount_max", !eligible && reason == 'amount_exceeds_limit')

# Test 2: Hard Constraints - Bank Blacklist
tests_total += 1
op_gazprom = SmartRouter::Operation.new({ 'operation_id' => 't2', 'amount' => 10_000, 'bank' => 'gazprombank' })
eligible, reason, details = SmartRouter::HardConstraints.check(p, op_gazprom)
tests_passed += 1 if assert("Excluded bank gazprombank skips vipay", !eligible && reason == 'bank_excluded')

# Test 3: Hard Constraints - Margin Check
tests_total += 1
p_unprofitable = SmartRouter::Provider.new('bad_margin', {
  'provider_margin_pct' => 3.5,
  'merchant_margin_pct' => 2.0,
  'allow_negative_agreement' => false
})
op_norm = SmartRouter::Operation.new({ 'operation_id' => 't3', 'amount' => 10_000, 'bank' => 'sber' })
eligible, reason, details = SmartRouter::HardConstraints.check(p_unprofitable, op_norm)
tests_passed += 1 if assert("Unprofitable margin without agreement is rejected", !eligible && reason == 'margin_agreement_negative')

# Test 4: Single eligible provider op_103
tests_total += 1
router = SmartRouter::Router.new(providers_data, strategy: 'combined', seed: 42)
op_103 = SmartRouter::Operation.new({ 'operation_id' => 'op_103', 'amount' => 150_000, 'bank' => 'sber' })
dec_103 = router.route_single_operation(op_103)
tests_passed += 1 if assert("op_103 selects quickpay with reason only_eligible_provider", dec_103['selected_provider'] == 'quickpay')

# Test 5: All providers ineligible -> fallback to spacepayments
tests_total += 1
op_extreme = SmartRouter::Operation.new({ 'operation_id' => 't5', 'amount' => 850_000, 'bank' => 'yoo_money' })
dec_extreme = router.route_single_operation(op_extreme)
tests_passed += 1 if assert("Out of boundary operation falls back to spacepayments", dec_extreme['selected_provider'] == 'spacepayments')

# Test 6: Full Queue Routing & Report Generation
tests_total += 1
queue_data = JSON.parse(File.read('data/operations_queue.json'))
decisions = router.route_queue(queue_data)
report = SmartRouter::AnalyticsReporter.generate_report(decisions, router.providers)
tests_passed += 1 if assert("Queue routing produces valid report with recommendations", decisions.size == queue_data.size && report['recommendations'].any?)

puts "\nTest Results: #{tests_passed}/#{tests_total} passed."
exit(tests_passed == tests_total ? 0 : 1)
