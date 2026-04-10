# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::RetryStrategy do
  def strategy_with(**attrs)
    settings = CMDx::Settings.new
    attrs.each { |k, v| settings.public_send(:"#{k}=", v) }
    described_class.new(settings)
  end

  describe "#retryable?" do
    it "is true when resolved retry_count > 0" do
      expect(strategy_with(retry_count: 1).retryable?).to be(true)
      expect(strategy_with(retry_count: 0).retryable?).to be(false)
    end
  end

  describe "#should_retry?" do
    it "checks exception class and attempt count against max_retries" do
      s = strategy_with(retry_count: 2, retry_on: [RuntimeError])
      err = RuntimeError.new("x")
      expect(s.should_retry?(err, 0)).to be(true)
      expect(s.should_retry?(err, 1)).to be(true)
      expect(s.should_retry?(err, 2)).to be(false)
      expect(s.should_retry?(ArgumentError.new("y"), 0)).to be(false)
    end
  end

  describe "#wait" do
    it "sleeps for delay plus jitter within range" do
      s = strategy_with(retry_delay: 0.02, retry_jitter: 0.03)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      s.wait
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
      expect(elapsed).to be >= 0.02
      expect(elapsed).to be < 0.08
    end

    it "returns immediately when delay and jitter are zero" do
      s = strategy_with(retry_delay: 0, retry_jitter: 0)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      s.wait
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
      expect(elapsed).to be < 0.01
    end
  end
end
