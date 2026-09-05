# frozen_string_literal: true

require 'json'
require_relative '../lib/smart_router'

module SmartRouter
  # Runner executes all test suites in the repository, validating compliance,
  # numeric precision, resilient fallbacks, and advanced modules.
  class MasterTestRunner
    SUITES = [
      { name: 'Comprehensive 40-Check Suite', file: 'comprehensive_test_suite.rb' },
      { name: 'Numeric & Crypto Precision Suite', file: 'test_numeric_precision.rb' },
      { name: 'Automated 68 Boundary & Burst Scenarios', file: 'test_automated_scenarios.rb' },
      { name: 'Advanced Modules (Rules, Anomaly, Ledger, Requisite)', file: 'test_advanced_modules.rb' },
      { name: 'Resilience, Policy Config & SLA Suite', file: 'test_policy_and_resilience.rb' },
      { name: 'Self-Healing & Replay Simulation Suite', file: 'test_self_healing_and_sla.rb' },
      { name: 'Fraud Risk & Cost Optimizer Suite', file: 'test_risk_and_cost_optimizers.rb' },
      { name: 'Dynamic Fees & Split Routing Engine Suite', file: 'test_fee_and_split_engines.rb' }
    ].freeze

    def self.run_all
      puts '=' * 68
      puts '   SMART PAYMENT ROUTER — MASTER VERIFICATION & TEST RUNNER'
      puts '=' * 68
      overall_start = Time.now

      all_passed = true
      total_suites = SUITES.size
      passed_suites = 0

      SUITES.each_with_index do |suite, idx|
        suite_path = File.expand_path(suite[:file], __dir__)
        print "\n[#{idx + 1}/#{total_suites}] Running #{suite[:name]}... "

        success = system("ruby #{suite_path} > /dev/null 2>&1")
        if success
          passed_suites += 1
          puts "SUCCESS [PASS]"
        else
          all_passed = false
          puts "FAILED [ERROR]"
        end
      end

      elapsed = (Time.now - overall_start).round(2)
      puts "\n" + ('=' * 68)
      puts "MASTER SUITE SUMMARY: #{passed_suites}/#{total_suites} SUITES PASSED (#{elapsed}s)"
      puts ('=' * 68)

      all_passed
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  success = SmartRouter::MasterTestRunner.run_all
  exit(success ? 0 : 1)
end
