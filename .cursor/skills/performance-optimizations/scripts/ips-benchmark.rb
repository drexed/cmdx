#!/usr/bin/env ruby
# frozen_string_literal: true

# USAGE: ruby .cursor/skills/performance-optimizations/scripts/ips-benchmark.rb
#
# Detailed iterations/second benchmark covering task execution scenarios,
# context access patterns, and nested task dispatch.
# Runs with comparison mode so regressions are immediately visible.

begin
  require "benchmark/ips"
rescue LoadError
  abort "Install with: gem install benchmark-ips"
end

require_relative "../../../../lib/cmdx"
require_relative "../../../../spec/support/helpers/task_builders"

include CMDx::Testing::TaskBuilders # rubocop:disable Style/MixinUsage

puts "CMDx IPS Benchmark"
puts "Ruby: #{RUBY_VERSION} | YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'enabled' : 'disabled'}"
puts

successful_task = create_successful_task
skipping_task   = create_skipping_task
failing_task    = create_failing_task
erroring_task   = create_erroring_task
nested_task     = create_nested_task(strategy: :swallow, status: :success)

puts "=== Task Execution ==="
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report("success")       { successful_task.execute }
  x.report("skip!")          { skipping_task.execute }
  x.report("fail!")          { failing_task.execute }
  x.report("error (rescue)") { erroring_task.execute }
  x.report("nested (3-deep)") { nested_task.execute }

  x.compare!
end

puts
puts "=== Context Construction ==="
small_hash = { a: 1, b: 2, c: 3 }
large_hash = (1..50).each_with_object({}) { |i, h| h[:"key_#{i}"] = i }
string_hash = { "a" => 1, "b" => 2, "c" => 3 }

Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report("Context.new (3 sym keys)")    { CMDx::Context.new(small_hash) }
  x.report("Context.new (3 str keys)")    { CMDx::Context.new(string_hash) }
  x.report("Context.new (50 sym keys)")   { CMDx::Context.new(large_hash) }
  x.report("Context.build (passthrough)") { CMDx::Context.build(CMDx::Context.new(small_hash)) }

  x.compare!
end

puts
puts "=== Context Access ==="
ctx = CMDx::Context.new(a: 1, b: 2, c: 3)

Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  x.report("ctx[:a] (bracket)")       { ctx[:a] }
  x.report("ctx.fetch(:a)")           { ctx.fetch(:a) }
  x.report("ctx.a (method_missing)")  { ctx.a }
  x.report("ctx.a = 1 (mm setter)")   { ctx.a = 1 }
  x.report("ctx.store(:a, 1)")        { ctx.store(:a, 1) }
  x.report("ctx.key?(:a)")            { ctx.key?(:a) }

  x.compare!
end
