# frozen_string_literal: true

require "benchmark/ips"
require_relative "../lib/cmdx"

CMDx.configure { |c| c.logger = Logger.new(File::NULL) }

# --- Test Tasks ---

class NoopTask < CMDx::Task
  def work; end
end

class FailSignalTask < CMDx::Task
  def work
    fail!("boom")
  end
end

class SkipSignalTask < CMDx::Task
  def work
    skip!("not needed")
  end
end

class NonHaltingFailTask < CMDx::Task
  def work
    fail!("deferred", halt: false)
  end
end

class AttrTask < CMDx::Task
  required :name, :string
  required :age, :integer
  optional :email, :string

  def work
    ctx[:greeting] = "Hello #{name}, age #{age}"
  end
end

class CallbackTask < CMDx::Task
  on_success :log_it
  on_failed :handle_fail
  before_execution :prep

  def work
    ctx[:done] = true
  end

  private

  def log_it; end
  def handle_fail; end
  def prep; end
end

class MiddlewareTask < CMDx::Task
  register CMDx::Middlewares::RuntimeTracker

  def work
    ctx[:done] = true
  end
end

class FullTask < CMDx::Task
  required :name, :string
  optional :count, :integer, default: 0
  on_success :after_success
  register CMDx::Middlewares::Correlate
  returns :output

  def work
    ctx[:output] = "processed #{name} (#{count})"
  end

  private

  def after_success; end
end

# --- Exception-based control flow comparison ---

class FaultException < CMDx::Fault
  def initialize
    @result = nil
    super(CMDx::Result.new(status: "failed", reason: "boom"))
  end
end

# --- Benchmarks ---

puts "=" * 60
puts "CMDx #{CMDx::VERSION} Performance Benchmarks"
puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "=" * 60
puts

Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  # 1. Control flow: throw/catch vs raise/rescue
  x.report("throw/catch (signal)") do
    catch(:cmdx_signal) { throw(:cmdx_signal, { status: :failed }) }
  end

  x.report("raise/rescue (exception)") do
    raise FaultException
  rescue CMDx::Fault
    nil
  end

  x.compare!
end

puts
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  # 2. Result construction
  x.report("Result.new (frozen)") do
    CMDx::Result.new(
      task_id: "abc", task_class: NoopTask, task_type: "noop",
      task_tags: [], state: "complete", status: "success",
      reason: nil, cause: nil, metadata: {}, strict: true,
      retries: 0, rolled_back: false, index: 0
    )
  end

  x.report("Outcome struct") do
    CMDx::Outcome.new
  end

  x.compare!
end

puts
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  # 3. Task execution throughput
  x.report("noop task") do
    CMDx::Chain.clear
    NoopTask.execute
  end

  x.report("fail! task") do
    CMDx::Chain.clear
    FailSignalTask.execute
  end

  x.report("skip! task") do
    CMDx::Chain.clear
    SkipSignalTask.execute
  end

  x.report("non-halting fail") do
    CMDx::Chain.clear
    NonHaltingFailTask.execute
  end

  x.compare!
end

puts
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  # 4. Attribute resolution
  x.report("3 attrs + coercion") do
    CMDx::Chain.clear
    AttrTask.execute(name: "Juan", age: "30", email: "j@x.com")
  end

  x.report("noop (no attrs)") do
    CMDx::Chain.clear
    NoopTask.execute
  end

  x.compare!
end

puts
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)

  # 5. Callbacks + middleware overhead
  x.report("with callbacks") do
    CMDx::Chain.clear
    CallbackTask.execute
  end

  x.report("with middleware") do
    CMDx::Chain.clear
    MiddlewareTask.execute
  end

  x.report("full stack") do
    CMDx::Chain.clear
    FullTask.execute(name: "test")
  end

  x.compare!
end
