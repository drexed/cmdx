# frozen_string_literal: true

require "memory_profiler"
require_relative "../lib/cmdx"

CMDx.configure { |c| c.logger = Logger.new(File::NULL) }

# ─────────────────────────────────────────────────────
# Test tasks (new system)
# ─────────────────────────────────────────────────────

class NoopTask < CMDx::Task
  def work; end
end

class FailTask < CMDx::Task
  def work
    fail!("boom")
  end
end

class SkipTask < CMDx::Task
  def work
    skip!("not needed")
  end
end

class AttrTask < CMDx::Task
  required :name, :string
  required :age, :integer
  optional :email, :string, default: "none"

  def work
    ctx[:greeting] = "Hello #{name}"
  end
end

class FullTask < CMDx::Task
  required :name, :string
  optional :count, :integer, default: 0
  on_success :after_success
  register CMDx::Middlewares::Correlate
  returns :output

  def work
    ctx[:output] = "processed #{name}"
  end

  private

  def after_success; end
end

# ─────────────────────────────────────────────────────
# Old-style simulation (raise/rescue + mutable Result)
# ─────────────────────────────────────────────────────

module OldStyle
  class FaultError < StandardError
    attr_reader :data
    def initialize(msg, data = {})
      @data = data
      super(msg)
    end
  end

  class MutableResult
    attr_accessor :state, :status, :reason, :cause, :metadata,
                  :strict, :retries, :rolled_back, :task_id,
                  :task_class, :task_type, :task_tags, :context,
                  :chain, :errors, :index

    def initialize
      @state = "initialized"
      @status = "success"
      @metadata = {}
      @strict = true
      @retries = 0
      @rolled_back = false
    end

    def success? = status == "success"
    def failed? = status == "failed"
    def to_h = { task_id:, status:, reason: }
  end

  # Simulates old executor pattern: create result, mutate it 10+ times, raise on fail
  def self.execute_noop
    result = MutableResult.new
    result.task_id = SecureRandom.uuid
    result.task_class = "OldNoop"
    result.task_type = "old.noop"
    result.task_tags = []
    result.state = "executing"
    # work (noop)
    result.state = "complete"
    result.context = {}
    result.chain = nil
    result.errors = {}
    result.index = 0
    result
  end

  def self.execute_fail
    result = MutableResult.new
    result.task_id = SecureRandom.uuid
    result.task_class = "OldFail"
    result.task_type = "old.fail"
    result.task_tags = []
    result.state = "executing"
    begin
      raise FaultError.new("boom", status: "failed")
    rescue FaultError => e
      result.status = "failed"
      result.reason = e.message
      result.cause = e
    end
    result.state = "interrupted"
    result.context = {}
    result.chain = nil
    result.errors = {}
    result.index = 0
    result
  end
end

# ─────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────

def profile(label, &block)
  # Warm up
  10.times { CMDx::Chain.clear; block.call }

  report = MemoryProfiler.report(top: 0, allow_files: "cmdx") do
    100.times { CMDx::Chain.clear; block.call }
  end

  total = report.total_allocated_memsize
  objects = report.total_allocated
  retained_mem = report.total_retained_memsize
  retained_obj = report.total_retained

  per_call_mem = total / 100
  per_call_obj = objects / 100

  {
    label:,
    per_call_mem:,
    per_call_obj:,
    retained_mem: retained_mem / 100,
    retained_obj: retained_obj / 100
  }
end

def profile_old(label, &block)
  10.times(&block)

  report = MemoryProfiler.report(top: 0) do
    100.times(&block)
  end

  total = report.total_allocated_memsize
  objects = report.total_allocated

  {
    label:,
    per_call_mem: total / 100,
    per_call_obj: objects / 100,
    retained_mem: report.total_retained_memsize / 100,
    retained_obj: report.total_retained / 100
  }
end

def print_comparison(title, old_data, new_data)
  puts title
  puts "-" * 70

  fmt = "  %-22s %8s  %8s  %10s"
  puts format(fmt, "", "Old", "New", "Reduction")
  puts format(fmt, "", "---", "---", "---------")

  mem_old = old_data[:per_call_mem]
  mem_new = new_data[:per_call_mem]
  mem_pct = mem_old.zero? ? "N/A" : "#{((1.0 - mem_new.to_f / mem_old) * 100).round(1)}%"

  obj_old = old_data[:per_call_obj]
  obj_new = new_data[:per_call_obj]
  obj_pct = obj_old.zero? ? "N/A" : "#{((1.0 - obj_new.to_f / obj_old) * 100).round(1)}%"

  puts format(fmt, "Allocated bytes/call", mem_old.to_s, mem_new.to_s, mem_pct)
  puts format(fmt, "Allocated objs/call", obj_old.to_s, obj_new.to_s, obj_pct)
  puts format(fmt, "Retained bytes/call", old_data[:retained_mem].to_s, new_data[:retained_mem].to_s, "")
  puts format(fmt, "Retained objs/call", old_data[:retained_obj].to_s, new_data[:retained_obj].to_s, "")
  puts
end

def print_solo(data)
  puts "  #{data[:label]}"
  puts "    Allocated: #{data[:per_call_mem]} bytes, #{data[:per_call_obj]} objects per call"
  puts "    Retained:  #{data[:retained_mem]} bytes, #{data[:retained_obj]} objects per call"
end

# ─────────────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────────────

puts "=" * 70
puts "CMDx #{CMDx::VERSION} Memory & Allocation Benchmarks"
puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "=" * 70
puts

# 1. Noop: old mutable vs new immutable
old_noop = profile_old("Old: noop (mutable Result, 10+ mutations)") { OldStyle.execute_noop }
new_noop = profile("New: noop task (frozen Result, signal-based)") { NoopTask.execute }
print_comparison("1. NOOP TASK — mutable Result vs frozen snapshot", old_noop, new_noop)

# 2. Fail: old raise/rescue vs new throw/catch
old_fail = profile_old("Old: fail (raise FaultError + rescue)") { OldStyle.execute_fail }
new_fail = profile("New: fail! (throw/catch signal)") { FailTask.execute }
print_comparison("2. FAIL TASK — raise/rescue vs throw/catch", old_fail, new_fail)

# 3. Control flow isolation: just the signal vs exception
puts "3. CONTROL FLOW ISOLATION — signal vs exception allocation"
puts "-" * 70

signal_report = MemoryProfiler.report(top: 0) do
  1000.times { catch(:cmdx_signal) { throw(:cmdx_signal, { status: :failed }) } }
end

exception_report = MemoryProfiler.report(top: 0) do
  1000.times do
    raise OldStyle::FaultError.new("boom", status: "failed")
  rescue OldStyle::FaultError
    nil
  end
end

sig_mem = signal_report.total_allocated_memsize / 1000
sig_obj = signal_report.total_allocated / 1000
exc_mem = exception_report.total_allocated_memsize / 1000
exc_obj = exception_report.total_allocated / 1000

fmt = "  %-25s %8s bytes  %6s objects"
puts format(fmt, "throw/catch (signal)", sig_mem.to_s, sig_obj.to_s)
puts format(fmt, "raise/rescue (exception)", exc_mem.to_s, exc_obj.to_s)
if exc_mem.positive? && sig_mem.positive?
  puts "  Signal uses #{(sig_mem.to_f / exc_mem * 100).round(1)}% of exception memory"
elsif sig_mem.zero?
  puts "  Signal: ZERO allocations — throw/catch allocates nothing beyond the hash literal"
end
puts

# 4. New system breakdown by feature
puts "4. NEW SYSTEM — per-feature allocation breakdown"
puts "-" * 70

results = []
results << profile("Noop task") { NoopTask.execute }
results << profile("Fail task") { FailTask.execute }
results << profile("Skip task") { SkipTask.execute }
results << profile("3 attrs + coercion") { AttrTask.execute(name: "Juan", age: "30", email: "j@x.com") }
results << profile("Full stack (attrs+cb+mw+ret)") { FullTask.execute(name: "test") }

results.each { |r| print_solo(r) }
puts

# 5. Result object comparison
puts "5. RESULT OBJECT — frozen snapshot vs mutable"
puts "-" * 70

frozen_report = MemoryProfiler.report(top: 0) do
  1000.times do
    CMDx::Result.new(
      task_id: "abc", task_class: NoopTask, task_type: "noop",
      task_tags: [], state: "complete", status: "success",
      reason: nil, cause: nil, metadata: {}, strict: true,
      retries: 0, rolled_back: false, index: 0
    )
  end
end

mutable_report = MemoryProfiler.report(top: 0) do
  1000.times do
    r = OldStyle::MutableResult.new
    r.task_id = "abc"
    r.task_class = "X"
    r.task_type = "x"
    r.task_tags = []
    r.state = "executing"
    r.state = "complete"
    r.status = "success"
    r.context = {}
    r.chain = nil
    r.errors = {}
    r.index = 0
  end
end

fr_mem = frozen_report.total_allocated_memsize / 1000
fr_obj = frozen_report.total_allocated / 1000
mu_mem = mutable_report.total_allocated_memsize / 1000
mu_obj = mutable_report.total_allocated / 1000

puts format(fmt, "Frozen Result.new", fr_mem.to_s, fr_obj.to_s)
puts format(fmt, "Mutable Result (10+ sets)", mu_mem.to_s, mu_obj.to_s)
pct = mu_mem.positive? ? "#{((1.0 - fr_mem.to_f / mu_mem) * 100).round(1)}%" : "N/A"
puts "  Frozen snapshot uses #{pct} less memory"
puts

# 6. Allocation hotspot detail for full task
puts "6. ALLOCATION HOTSPOTS — Full stack task (top 15 locations)"
puts "-" * 70

detail = MemoryProfiler.report(top: 15, allow_files: "cmdx") do
  50.times { CMDx::Chain.clear; FullTask.execute(name: "test") }
end

detail.pretty_print(to_file: $stdout, detailed_report: false, scale_bytes: true,
                    allocated_strings: 0, retained_strings: 0)
