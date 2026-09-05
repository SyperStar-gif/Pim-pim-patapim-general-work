#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../lib/smart_router'

options = {
  queue: File.exist?('operations_queue_test.json') ? 'operations_queue_test.json' : 'data/operations_queue.json',
  providers: 'data/providers.json',
  strategy: 'combined',
  output: 'routing_decisions_test.json',
  report: 'routing_report_test.json',
  seed: 42
}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby bin/route_payments.rb [options]'
  opts.on('-q', '--queue FILE', 'Path to operations queue JSON') { |v| options[:queue] = v }
  opts.on('-p', '--providers FILE', 'Path to providers JSON') { |v| options[:providers] = v }
  opts.on('-s', '--strategy STRATEGY', 'Routing strategy (combined, traffic_share, volume_share, cascade_priority, amount_tier, conversion_boost, rate_limit_intensity, financial_obligations)') { |v| options[:strategy] = v }
  opts.on('-o', '--output FILE', 'Path to output decisions JSON') { |v| options[:output] = v }
  opts.on('-r', '--report FILE', 'Path to output report JSON') { |v| options[:report] = v }
  opts.on('--seed INT', Integer, 'Deterministic random seed') { |v| options[:seed] = v }
end.parse!

puts ">>> SMART PAYMENT ROUTER ENGINE <<<"
puts "Strategy:  #{options[:strategy]}"
puts "Queue:     #{options[:queue]}"
puts "Providers: #{options[:providers]}"

providers_data = JSON.parse(File.read(options[:providers]))
queue_data = JSON.parse(File.read(options[:queue]))

router = SmartRouter::Router.new(providers_data, strategy: options[:strategy], seed: options[:seed])
decisions = router.route_queue(queue_data)

# Write decisions
File.write(options[:output], JSON.pretty_generate(decisions))
# Also write to routing_decisions.json if outputting to test
File.write('routing_decisions.json', JSON.pretty_generate(decisions)) if options[:output] != 'routing_decisions.json'

# Generate & write report
report = SmartRouter::AnalyticsReporter.generate_report(decisions, router.providers)
File.write(options[:report], JSON.pretty_generate(report))
File.write('routing_report.json', JSON.pretty_generate(report)) if options[:report] != 'routing_report.json'

puts "\n[SUCCESS] Routed #{decisions.size} operations successfully!"
puts "Decisions saved to: #{options[:output]}"
puts "Report saved to:    #{options[:report]}"

puts "\nSummary Distribution:"
report['distribution'].each do |p_id, stats|
  puts "  - #{p_id}: #{stats['count']} ops (#{stats['share_pct']}%, target: #{stats['target_pct']}%)"
end

puts "\nRecommendations:"
report['recommendations'].each do |rec|
  puts "  * #{rec}"
end
