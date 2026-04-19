#!/usr/bin/env ruby
# frozen_string_literal: true

# USAGE: ruby .cursor/skills/performance-optimizations/scripts/allocation-trace.rb
#
# Traces object allocations during a single CMDx task execution cycle.
# Reports per-class allocation counts sorted by frequency.

require_relative "../../../../lib/cmdx"
require_relative "../../../../spec/support/helpers/task_builders"

include CMDx::Testing::TaskBuilders # rubocop:disable Style/MixinUsage

SCENARIOS = {
  "success" => -> { create_successful_task },
  "skipped" => -> { create_skipping_task },
  "failed" => -> { create_failing_task },
  "errored" => -> { create_erroring_task }
}.freeze

def trace_allocations(label, task_class)
  task_class.execute

  GC.start
  GC.disable

  alloc_counts = Hash.new(0)

  ObjectSpace.trace_object_allocations_start

  result = task_class.execute

  ObjectSpace.trace_object_allocations_stop

  ObjectSpace.each_object do |obj|
    file = ObjectSpace.allocation_sourcefile(obj)
    next unless file&.include?("cmdx")

    klass = obj.class.name || obj.class.to_s
    alloc_counts[klass] += 1
  end

  GC.enable

  puts "--- #{label} (status: #{result.status}) ---"
  alloc_counts.sort_by { |_, count| -count }.each do |klass, count|
    puts "  #{klass.ljust(30)} #{count}"
  end
  puts
end

puts "CMDx Allocation Trace"
puts "Ruby: #{RUBY_VERSION} | YJIT: #{defined?(RubyVM::YJIT) ? 'available' : 'unavailable'}"
puts

SCENARIOS.each do |label, builder|
  task_class = builder.call
  trace_allocations(label, task_class)
end
