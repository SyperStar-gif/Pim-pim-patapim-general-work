#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../lib/smart_router'

# Automated Validation Script for Payment Routing Decisions & Report
# Usage:
#   ruby data/validate.rb [--decisions routing_decisions_test.json] [--report routing_report_test.json] [--providers data/providers.json]

options = {
  decisions: File.exist?('routing_decisions_test.json') ? 'routing_decisions_test.json' : 'routing_decisions.json',
  report: File.exist?('routing_report_test.json') ? 'routing_report_test.json' : 'routing_report.json',
  providers: 'data/providers.json',
  queue: File.exist?('operations_queue_test.json') ? 'operations_queue_test.json' : 'data/operations_queue.json'
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby data/validate.rb [options]'
  opts.on('-d', '--decisions FILE', 'Path to routing decisions JSON') { |v| options[:decisions] = v }
  opts.on('-r', '--report FILE', 'Path to routing report JSON') { |v| options[:report] = v }
  opts.on('-p', '--providers FILE', 'Path to providers JSON') { |v| options[:providers] = v }
  opts.on('-q', '--queue FILE', 'Path to operations queue JSON') { |v| options[:queue] = v }
end.parse!

puts "=================================================="
puts "  SMART PAYMENT ROUTER — AUTO-VALIDATION SUITE    "
puts "=================================================="
puts "Checking decisions file: #{options[:decisions]}"
puts "Checking report file:    #{options[:report]}"
puts "Using providers:         #{options[:providers]}"
puts "Using queue:             #{options[:queue]}"
puts "--------------------------------------------------"

errors = []
warnings = []
passed_checks = 0

# 1. Load Providers
providers = {}
if File.exist?(options[:providers])
  begin
    providers_raw = JSON.parse(File.read(options[:providers]))
    providers = if providers_raw.is_a?(Hash) && providers_raw['providers'].is_a?(Array)
                  providers_raw['providers'].each_with_object({}) do |p, h|
                    h[p['payment_system'] || p['id']] = p
                  end
                elsif providers_raw.is_a?(Hash)
                  providers_raw
                else
                  {}
                end
    puts "  [PASS] Providers JSON loaded successfully (#{providers.keys.size} providers)"
    passed_checks += 1
  rescue => e
    errors << "Failed to parse providers JSON: #{e.message}"
  end
else
  errors << "Providers file not found: #{options[:providers]}"
end

# 2. Load Queue
queue_map = {}
if File.exist?(options[:queue])
  begin
    queue_data = JSON.parse(File.read(options[:queue]))
    queue_data.each { |op| queue_map[op['operation_id']] = op }
    puts "  [PASS] Operations queue loaded successfully (#{queue_map.size} operations)"
    passed_checks += 1
  rescue => e
    errors << "Failed to parse operations queue JSON: #{e.message}"
  end
else
  warnings << "Operations queue file not found: #{options[:queue]}"
end

# 3. Validate Decisions File
decisions = nil
unless File.exist?(options[:decisions])
  errors << "CRITICAL: Decisions file missing: #{options[:decisions]}"
else
  begin
    decisions = JSON.parse(File.read(options[:decisions]))
    unless decisions.is_a?(Array)
      errors << "Decisions file must contain a JSON array, got #{decisions.class}"
    else
      puts "  [PASS] Decisions JSON loaded (#{decisions.size} decisions recorded)"
      passed_checks += 1
    end
  rescue => e
    errors << "CRITICAL: Invalid JSON in decisions file: #{e.message}"
  end
end

if decisions.is_a?(Array)
  decisions.each_with_index do |dec, idx|
    prefix = "Decision ##{idx + 1} (#{dec['operation_id'] || 'unknown'}):"

    # Required fields
    %w[operation_id selected_provider attempts simulated_result latency_sec].each do |field|
      unless dec.key?(field)
        errors << "#{prefix} Missing required field '#{field}'"
      end
    end

    # Validate simulated_result
    valid_results = %w[approved rejected expired]
    if dec['simulated_result'] && !valid_results.include?(dec['simulated_result'])
      errors << "#{prefix} Invalid simulated_result '#{dec['simulated_result']}'. Allowed: #{valid_results.join(', ')}"
    end

    # Validate latency_sec
    if dec['latency_sec'] && (!dec['latency_sec'].is_a?(Numeric) || dec['latency_sec'] <= 0)
      errors << "#{prefix} latency_sec must be positive numeric, got #{dec['latency_sec'].inspect}"
    end

    # Validate attempts array
    attempts = dec['attempts']
    if attempts.nil? || !attempts.is_a?(Array) || attempts.empty?
      errors << "#{prefix} 'attempts' must be a non-empty array"
    else
      selected_attempts = attempts.select { |a| a['decision'] == 'selected' }
      if selected_attempts.size != 1
        errors << "#{prefix} Must contain exactly one attempt with decision='selected', found #{selected_attempts.size}"
      else
        last_selected = selected_attempts.first
        if last_selected['provider'] != dec['selected_provider']
          errors << "#{prefix} selected attempt provider '#{last_selected['provider']}' does not match selected_provider '#{dec['selected_provider']}'"
        end
      end

      # Check attempt format
      attempts.each_with_index do |att, a_idx|
        att_prefix = "#{prefix} Attempt ##{a_idx + 1} (#{att['provider']}):"
        unless %w[selected skipped].include?(att['decision'])
          errors << "#{att_prefix} Invalid decision '#{att['decision']}'. Must be 'selected' or 'skipped'"
        end
        if att['reason'].to_s.strip.empty?
          errors << "#{att_prefix} Missing or empty reason"
        end
      end
    end

    # Validate Hard Constraints for the chosen provider against queue operation
    op = queue_map[dec['operation_id']]
    selected_p = providers[dec['selected_provider']]

    if selected_p && op
      amount = op['amount'].to_f
      bank = op['bank'].to_s.downcase

      # Check status
      if selected_p['status'] != 'active'
        errors << "#{prefix} Selected provider '#{dec['selected_provider']}' is not active (status=#{selected_p['status']})"
      end

      # Check amount limits
      if selected_p['limit_amount_min'] && amount < selected_p['limit_amount_min'].to_f
        errors << "#{prefix} Amount #{amount} is below limit_amount_min #{selected_p['limit_amount_min']} for #{dec['selected_provider']}"
      end
      if selected_p['limit_amount_max'] && amount > selected_p['limit_amount_max'].to_f
        errors << "#{prefix} Amount #{amount} exceeds limit_amount_max #{selected_p['limit_amount_max']} for #{dec['selected_provider']}"
      end

      # Check bank filters
      norm_bank = SmartRouter::Operation.normalize_bank(bank)
      if selected_p['banks'] && !selected_p['banks'].empty?
        norm_supported = selected_p['banks'].map { |b| SmartRouter::Operation.normalize_bank(b) }
        unless norm_supported.include?(norm_bank) || selected_p['banks'].map(&:downcase).include?(bank)
          errors << "#{prefix} Bank '#{bank}' is not supported by #{dec['selected_provider']} (supported: #{selected_p['banks'].join(', ')})"
        end
      end
      if selected_p['exclude_banks'].is_a?(Array)
        norm_excluded = selected_p['exclude_banks'].map { |b| SmartRouter::Operation.normalize_bank(b) }
        if norm_excluded.include?(norm_bank) || selected_p['exclude_banks'].map(&:downcase).include?(bank)
          errors << "#{prefix} Bank '#{bank}' is in exclude_banks for #{dec['selected_provider']}"
        end
      end

      # Check margin
      p_margin = selected_p['provider_margin_pct'].to_f
      m_margin = selected_p['merchant_margin_pct'].to_f
      allow_neg = selected_p['allow_negative_agreement'] == true
      if p_margin > m_margin && !allow_neg
        errors << "#{prefix} Provider margin #{p_margin}% exceeds merchant margin #{m_margin}% without negative agreement"
      end

      # Check requisites
      if selected_p['available_requisites'].to_i <= 0
        errors << "#{prefix} Selected provider #{dec['selected_provider']} has 0 available requisites"
      end
    end
  end

  if errors.empty?
    puts "  [PASS] All routing decisions passed schema and hard-constraint checks!"
    passed_checks += 1
  end
end

# 4. Validate Routing Report File
if File.exist?(options[:report])
  begin
    report = JSON.parse(File.read(options[:report]))
    puts "  [PASS] Report JSON loaded successfully"
    passed_checks += 1

    # Check report keys
    %w[period total_operations distribution skip_reasons projected_daily_utilization recommendations].each do |k|
      unless report.key?(k)
        errors << "Report missing required section '#{k}'"
      end
    end

    if report['distribution'].is_a?(Hash)
      report['distribution'].each do |p_id, stats|
        %w[count share_pct target_pct].each do |sk|
          unless stats.key?(sk)
            errors << "Distribution for '#{p_id}' missing '#{sk}'"
          end
        end
      end
      puts "  [PASS] Report distribution schema verified"
      passed_checks += 1
    end

    if report['recommendations'].is_a?(Array) && !report['recommendations'].empty?
      puts "  [PASS] Recommendations found (#{report['recommendations'].size} actionable insights)"
      passed_checks += 1
    else
      warnings << "Report recommendations should be a non-empty array"
    end
  rescue => e
    errors << "CRITICAL: Invalid JSON in report file: #{e.message}"
  end
else
  errors << "CRITICAL: Report file missing: #{options[:report]}"
end

puts "--------------------------------------------------"
puts "VALIDATION SUMMARY:"
puts "  Passed checks: #{passed_checks}"
puts "  Warnings:      #{warnings.size}"
puts "  Errors:        #{errors.size}"

if warnings.any?
  puts "\nWARNINGS:"
  warnings.each { |w| puts "  - #{w}" }
end

if errors.any?
  puts "\nERRORS:"
  errors.each { |e| puts "  [FAIL] #{e}" }
  puts "\nRESULT: FAILED (Exit 1)"
  exit 1
else
  puts "\nRESULT: ALL CHECKS PASSED (Exit 0)!"
  exit 0
end
