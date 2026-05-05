#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark harness — runs all suites for a single CMDx version.
#
# USAGE (called by compare.rb, not directly):
#   ruby benchmark/harness.rb --root /path/to/worktree --version v1 --output tmp/v1.json
#
# Requires benchmark-ips, memory_profiler, get_process_mem to be installed.

require "optparse"
require "json"

options = {}
OptionParser.new do |opts|
  opts.on("--root PATH", "Path to CMDx worktree root") { |v| options[:root] = v }
  opts.on("--version LABEL", "Version label (v1 or v2)") { |v| options[:version] = v }
  opts.on("--output PATH", "JSON output file path") { |v| options[:output] = v }
end.parse!

root    = options.fetch(:root)
version = options.fetch(:version)
output  = options.fetch(:output)

$LOAD_PATH.unshift("#{root}/lib")
require "cmdx"
require "#{root}/spec/support/helpers/task_builders"
require "#{root}/spec/support/helpers/workflow_builders"

include CMDx::Testing::TaskBuilders # rubocop:disable Style/MixinUsage
include CMDx::Testing::WorkflowBuilders # rubocop:disable Style/MixinUsage

CMDx.reset_configuration!
CMDx.configuration.logger = Logger.new(nil)

require "benchmark/ips"
require "memory_profiler"
require "get_process_mem"

results = {
  version:,
  cmdx_version: CMDx::VERSION,
  ruby: RUBY_VERSION,
  yjit: defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enabled?) && RubyVM::YJIT.enabled?,
  timestamp: Time.now.utc.iso8601,
  suites: {}
}

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------
successful_task = create_successful_task
skipping_task   = create_skipping_task
failing_task    = create_failing_task
erroring_task   = create_erroring_task
nested_task     = create_nested_task(strategy: :swallow, status: :success)

successful_workflow = create_successful_workflow
failing_workflow    = create_failing_workflow

small_hash  = { a: 1, b: 2, c: 3 }
large_hash  = (1..50).to_h { |i| [:"key_#{i}", i] }
string_hash = { "a" => 1, "b" => 2, "c" => 3 }

# Warm up everything once
[successful_task, skipping_task, failing_task, erroring_task, nested_task,
 successful_workflow, failing_workflow].each { |t| t.execute rescue nil } # rubocop:disable Style/RescueModifier

# ---------------------------------------------------------------------------
# Helper: capture benchmark-ips results as a hash
# ---------------------------------------------------------------------------
def capture_ips(warmup: 1, time: 3)
  collected = {}
  job = nil
  Benchmark.ips do |x|
    x.config(warmup:, time:, quiet: true)
    yield(x)
    job = x
  end
  job.full_report.entries.each do |e|
    collected[e.label] = { ips: e.ips.round(1), error_pct: e.error_percentage.round(2) }
  end
  collected
end

# ---------------------------------------------------------------------------
# 1. IPS — Task Execution
# ---------------------------------------------------------------------------
warn "[#{version}] Running IPS: task execution..."
results[:suites][:ips_tasks] = capture_ips do |x|
  x.report("success") { successful_task.execute }
  x.report("skip!")            { skipping_task.execute }
  x.report("fail!")            { failing_task.execute }
  x.report("error (rescue)")   { erroring_task.execute }
  x.report("nested (3-deep)")  { nested_task.execute }
end

# ---------------------------------------------------------------------------
# 2. IPS — Workflow Execution
# ---------------------------------------------------------------------------
warn "[#{version}] Running IPS: workflow execution..."
results[:suites][:ips_workflows] = capture_ips do |x|
  x.report("workflow success (3 tasks)") { successful_workflow.execute }
  x.report("workflow failure (halting)")  { failing_workflow.execute }
end

# ---------------------------------------------------------------------------
# 3. IPS — Context
# ---------------------------------------------------------------------------
warn "[#{version}] Running IPS: context..."
results[:suites][:ips_context] = capture_ips do |x|
  x.report("Context.new (3 sym keys)")    { CMDx::Context.new(small_hash) }
  x.report("Context.new (3 str keys)")    { CMDx::Context.new(string_hash) }
  x.report("Context.new (50 sym keys)")   { CMDx::Context.new(large_hash) }
  x.report("Context.build (passthrough)") { CMDx::Context.build(CMDx::Context.new(small_hash)) }
end

ctx = CMDx::Context.new(a: 1, b: 2, c: 3)
results[:suites][:ips_context_access] = capture_ips do |x|
  x.report("ctx[:a] (bracket)")      { ctx[:a] }
  x.report("ctx.fetch(:a)")          { ctx.fetch(:a) }
  x.report("ctx.a (method_missing)") { ctx.a }
  x.report("ctx.a = 1 (mm setter)")  { ctx.a = 1 }
  x.report("ctx.key?(:a)")           { ctx.key?(:a) }
end

# ---------------------------------------------------------------------------
# 4. Memory Profiling (memory_profiler)
# ---------------------------------------------------------------------------
warn "[#{version}] Running memory profiling..."

def memory_profile(label, task_class)
  task_class.execute rescue nil # rubocop:disable Style/RescueModifier
  report = MemoryProfiler.report(allow_files: "cmdx") { task_class.execute rescue nil } # rubocop:disable Style/RescueModifier
  {
    label:,
    total_allocated_memsize: report.total_allocated_memsize,
    total_allocated_objects: report.total_allocated,
    total_retained_memsize: report.total_retained_memsize,
    total_retained_objects: report.total_retained
  }
end

results[:suites][:memory] = [
  memory_profile("success", successful_task),
  memory_profile("skip!", skipping_task),
  memory_profile("fail!", failing_task),
  memory_profile("error (rescue)", erroring_task),
  memory_profile("nested (3-deep)", nested_task),
  memory_profile("workflow success", successful_workflow),
  memory_profile("workflow failure", failing_workflow)
]

# ---------------------------------------------------------------------------
# 5. Object Allocations (ObjectSpace)
# ---------------------------------------------------------------------------
warn "[#{version}] Running allocation trace..."

def allocation_trace(label, task_class)
  task_class.execute rescue nil # rubocop:disable Style/RescueModifier

  GC.start
  GC.disable

  alloc_counts = Hash.new(0)
  ObjectSpace.trace_object_allocations_start
  task_class.execute rescue nil # rubocop:disable Style/RescueModifier
  ObjectSpace.trace_object_allocations_stop

  ObjectSpace.each_object do |obj|
    file = ObjectSpace.allocation_sourcefile(obj)
    next unless file&.include?("cmdx")

    klass = obj.class.name || obj.class.to_s
    alloc_counts[klass] += 1
  end

  GC.enable
  ObjectSpace.trace_object_allocations_clear

  { label:, allocations: alloc_counts.sort_by { |_, c| -c }.first(15).to_h }
end

results[:suites][:allocations] = [
  allocation_trace("success", successful_task),
  allocation_trace("nested (3-deep)", nested_task),
  allocation_trace("workflow success", successful_workflow)
]

# ---------------------------------------------------------------------------
# 6. RSS (get_process_mem)
# ---------------------------------------------------------------------------
warn "[#{version}] Running RSS measurement..."

iterations = 1000
mem = GetProcessMem.new

GC.start
rss_before = mem.mb

iterations.times { successful_task.execute }
GC.start
rss_after_tasks = mem.mb

iterations.times { successful_workflow.execute }
GC.start
rss_after_workflows = mem.mb

results[:suites][:rss] = {
  iterations:,
  before_mb: rss_before.round(2),
  after_tasks_mb: rss_after_tasks.round(2),
  after_workflows_mb: rss_after_workflows.round(2),
  task_growth_mb: (rss_after_tasks - rss_before).round(2),
  workflow_growth_mb: (rss_after_workflows - rss_after_tasks).round(2)
}

# ---------------------------------------------------------------------------
# 7. GC Stats
# ---------------------------------------------------------------------------
warn "[#{version}] Running GC stats..."

GC.start
gc_before = GC.stat

iterations.times { successful_task.execute }
gc_after_tasks = GC.stat

iterations.times { successful_workflow.execute }
gc_after_all = GC.stat

gc_keys = %i[total_allocated_objects heap_live_slots major_gc_count minor_gc_count]

results[:suites][:gc_stats] = {
  iterations:,
  after_tasks: gc_keys.to_h { |k| [k, gc_after_tasks[k] - gc_before[k]] },
  after_workflows: gc_keys.to_h { |k| [k, gc_after_all[k] - gc_after_tasks[k]] }
}

# ---------------------------------------------------------------------------
# 8. YJIT Comparison (if available)
# ---------------------------------------------------------------------------
if defined?(RubyVM::YJIT)
  warn "[#{version}] Running YJIT comparison..."

  yjit_results = {}

  # Without YJIT (already the default state if not enabled)
  unless RubyVM::YJIT.enabled?
    yjit_results[:no_yjit] = capture_ips(warmup: 1, time: 2) do |x|
      x.report("success") { successful_task.execute }
      x.report("workflow success (3 tasks)") { successful_workflow.execute }
    end
  end

  RubyVM::YJIT.enable
  yjit_results[:with_yjit] = capture_ips(warmup: 1, time: 2) do |x|
    x.report("success") { successful_task.execute }
    x.report("workflow success (3 tasks)") { successful_workflow.execute }
  end

  if yjit_results[:no_yjit]
    speedups = {}
    yjit_results[:no_yjit].each do |label, base|
      fast = yjit_results[:with_yjit][label]
      speedups[label] = (fast[:ips] / base[:ips]).round(2) if fast && base[:ips].positive?
    end
    yjit_results[:speedup] = speedups
  end

  results[:suites][:yjit] = yjit_results
else
  warn "[#{version}] YJIT not available, skipping..."
  results[:suites][:yjit] = { error: "YJIT not available" }
end

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------
File.write(output, JSON.pretty_generate(results))
warn "[#{version}] Results written to #{output}"
