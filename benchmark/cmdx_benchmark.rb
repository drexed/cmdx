# frozen_string_literal: true

require "bundler/setup"
require_relative "../lib/cmdx"

CMDx.configuration.logger = Logger.new(nil)

klass = Class.new(CMDx::Task) do
  required :n, type: :integer

  def work
    context[:out] = n + 1
  end
end

n = 20_000
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
n.times { klass.execute(n: 1) }
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
puts format("Task.execute x%<n>d: %<sec>.3fs (%<rps>.1f runs/s)", n: n, sec: elapsed, rps: n / elapsed)
