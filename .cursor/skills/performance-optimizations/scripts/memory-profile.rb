#!/usr/bin/env ruby
# frozen_string_literal: true

# USAGE: ruby .cursor/skills/performance-optimizations/scripts/memory-profile.rb [scenario]
#
# Per-file and per-line memory allocation report using the memory_profiler gem.
# Scenarios: success (default), skipped, failed, errored, nested
#
# Output includes:
#   - Total allocated/retained memory and objects
#   - Top allocation sites by file and line
#   - Per-gem breakdown

begin
  require "memory_profiler"
rescue LoadError
  abort "Install with: gem install memory_profiler"
end

require_relative "../../../../lib/cmdx"
require_relative "../../../../spec/support/helpers/task_builders"

include CMDx::Testing::TaskBuilders # rubocop:disable Style/MixinUsage

SCENARIOS = {
  "success" => -> { create_successful_task },
  "skipped" => -> { create_skipping_task },
  "failed" => -> { create_failing_task },
  "errored" => -> { create_erroring_task },
  "nested" => -> { create_nested_task(strategy: :swallow, status: :success) }
}.freeze

scenario = ARGV.fetch(0, "success")
builder  = SCENARIOS.fetch(scenario) { abort "Unknown scenario: #{scenario}. Choose: #{SCENARIOS.keys.join(', ')}" }

task_class = builder.call

# Warm up to avoid measuring autoload/class creation
task_class.execute

puts "CMDx Memory Profile — #{scenario}"
puts "Ruby: #{RUBY_VERSION} | YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'enabled' : 'disabled'}"
puts

report = MemoryProfiler.report(allow_files: "cmdx") do
  task_class.execute
end

report.pretty_print(
  detailed_report: true,
  allocated_strings: 10,
  retained_strings: 5,
  scale_bytes: true
)
