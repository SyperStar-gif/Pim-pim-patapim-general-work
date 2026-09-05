# frozen_string_literal: true

require 'json'
require 'benchmark'
require_relative '../lib/smart_router'

module SmartRouter
  # BenchmarkRunner measures router latency, throughput, and memory allocations.
  class BenchmarkRunner
    def self.run(iterations = 1000)
      puts '=' * 60
      puts "  SMART PAYMENT ROUTER — HIGH THROUGHPUT BENCHMARK (#{iterations} ops)"
      puts '=' * 60

      providers_path = File.expand_path('../data/providers.json', __dir__)
      providers_data = JSON.parse(File.read(providers_path))

      sample_ops = [
        { 'operation_id' => 'bench_1', 'amount' => 1500, 'bank' => 'sber' },
        { 'operation_id' => 'bench_2', 'amount' => 45000, 'bank' => 'tinkoff' },
        { 'operation_id' => 'bench_3', 'amount' => 85000, 'bank' => 'vtb' },
        { 'operation_id' => 'bench_4', 'amount' => 175000, 'bank' => 'alfa' },
        { 'operation_id' => 'bench_5', 'amount' => 250000, 'bank' => 'sber' }
      ]

      router = SmartRouter::Router.new(
        providers_data,
        strategy: 'combined'
      )

      realtime = Benchmark.realtime do
        iterations.times do |i|
          template = sample_ops[i % sample_ops.size]
          op = template.merge('operation_id' => "bench_#{i}")
          router.route_single(op)
        end
      end

      ops_per_sec = (iterations / realtime).round(2)
      avg_latency_ms = ((realtime / iterations) * 1000).round(3)

      puts "Total Time:       #{realtime.round(4)} sec"
      puts "Throughput:       #{ops_per_sec} ops/sec"
      puts "Average Latency:  #{avg_latency_ms} ms/op"
      puts '=' * 60

      {
        iterations: iterations,
        total_time_sec: realtime.round(4),
        ops_per_sec: ops_per_sec,
        avg_latency_ms: avg_latency_ms
      }
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  count = (ARGV[0] || 1000).to_i
  SmartRouter::BenchmarkRunner.run(count)
end
