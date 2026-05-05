#!/usr/bin/env ruby
# frozen_string_literal: true

# USAGE: ruby .cursor/skills/performance-optimizations/scripts/yjit-compare.rb
#
# Runs the same benchmark suite twice — once without YJIT and once with YJIT
# enabled — then prints a side-by-side comparison with speedup ratios.
# Requires Ruby 3.3+ for runtime YJIT enable/disable.

begin
  require "benchmark/ips"
rescue LoadError
  abort "Install with: gem install benchmark-ips"
end

require_relative "../../../../lib/cmdx"
require_relative "../../../../spec/support/helpers/task_builders"

include CMDx::Testing::TaskBuilders # rubocop:disable Style/MixinUsage

puts "CMDx YJIT Comparison"
puts "Ruby: #{RUBY_VERSION}"

abort "YJIT not available on this Ruby build. Use CRuby 3.1+ built with --enable-yjit." unless defined?(RubyVM::YJIT)

successful_task = create_successful_task
skipping_task   = create_skipping_task
failing_task    = create_failing_task
ctx_hash        = { a: 1, b: 2, c: 3 }

BENCHMARKS = {
  "Task.execute (success)" => -> { successful_task.execute },
  "Task.execute (skip!)" => -> { skipping_task.execute },
  "Task.execute (fail!)" => -> { failing_task.execute },
  "Context.new (3 keys)" => -> { CMDx::Context.new(ctx_hash) },
  "ctx[:a] (bracket)" => -> { CMDx::Context.new(ctx_hash)[:a] }
}.freeze

def run_suite(label)
  puts
  puts "--- #{label} ---"
  results = {}

  BENCHMARKS.each do |name, work|
    report = Benchmark::IPS::Job.new
    report.config(warmup: 1, time: 3, quiet: true)
    report.report(name, &work)
    report.run

    entry = report.entries.first
    results[name] = entry.ips
    puts "  #{name.ljust(30)} #{format('%.1f', entry.ips)} i/s"
  end

  results
end

no_yjit = run_suite("Without YJIT")

RubyVM::YJIT.enable
yjit = run_suite("With YJIT")

puts
puts "=== Speedup (YJIT / no-YJIT) ==="
BENCHMARKS.each_key do |name|
  base  = no_yjit[name]
  fast  = yjit[name]
  ratio = fast / base

  bar = "|" + ("#" * [(ratio * 20).to_i, 60].min)
  puts "  #{name.ljust(30)} #{format('%.2fx', ratio)}  #{bar}"
end
