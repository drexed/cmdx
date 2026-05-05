# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Task retry", type: :feature do
  describe "without retry_on" do
    it "returns success with retries: 0" do
      result = create_successful_task.execute

      expect(result).to have_attributes(status: CMDx::Signal::SUCCESS, retries: 0, retried?: false)
    end
  end

  describe "transient errors within the limit" do
    it "retries until success and reports the retry count" do
      task = create_flaky_task(failures: 2) do
        retry_on CMDx::TestError, limit: 3, delay: 0
      end

      result = task.execute

      expect(result).to have_attributes(
        status: CMDx::Signal::SUCCESS,
        retries: 2,
        retried?: true
      )
      expect(result.context).to have_attributes(executed: %i[success])
    end
  end

  describe "exhausting retries" do
    let(:task) do
      create_flaky_task(failures: 5) do
        retry_on CMDx::TestError, limit: 2, delay: 0
      end
    end

    it "captures the error as a failed result under execute" do
      result = task.execute

      expect(result).to have_attributes(
        status: CMDx::Signal::FAILED,
        reason: start_with("[CMDx::TestError]"),
        cause: be_a(CMDx::TestError)
      )
    end

    it "re-raises the original error under execute!" do
      expect { task.execute! }.to raise_error(CMDx::TestError, /flaky attempt/)
    end
  end

  describe "selective matching" do
    it "does not retry for unmatched exceptions" do
      task = create_erroring_task do
        retry_on ArgumentError, limit: 3, delay: 0
      end

      expect(task.execute).to have_attributes(status: CMDx::Signal::FAILED, retries: 0)
    end

    it "supports multiple exception classes" do
      counter = { n: 0 }
      task = create_task_class(name: "MixedError") do
        retry_on CMDx::TestError, ArgumentError, limit: 3, delay: 0
        define_method(:work) do
          counter[:n] += 1
          raise(counter[:n].odd? ? CMDx::TestError : ArgumentError, "try #{counter[:n]}")
        end
      end

      result = task.execute

      expect(result).to have_attributes(status: CMDx::Signal::FAILED, retries: 3)
      expect(counter[:n]).to eq(4)
    end

    it "does not retry signal-based failures (fail!)" do
      task = create_failing_task(reason: "stop") do
        retry_on CMDx::TestError, limit: 3, delay: 0
      end

      expect(task.execute).to have_attributes(
        status: CMDx::Signal::FAILED,
        reason: "stop",
        retries: 0
      )
    end
  end

  describe "jitter" do
    it "accepts exponential jitter without affecting success semantics" do
      task = create_flaky_task(failures: 2) do
        retry_on CMDx::TestError, limit: 3, delay: 0, jitter: :exponential
      end

      expect(task.execute).to have_attributes(status: CMDx::Signal::SUCCESS, retries: 2)
    end

    it "accepts a Proc jitter that receives attempt and delay" do
      seen = []
      jitter = lambda do |attempt, delay|
        seen << [attempt, delay]
        0
      end
      task = create_flaky_task(failures: 2) do
        retry_on(CMDx::TestError, limit: 3, delay: 0.0001, jitter:)
      end

      task.execute

      expect(seen.map(&:first)).to eq([0, 1])
      expect(seen.map(&:last)).to all(eq(0.0001))
    end
  end

  describe "inheritance" do
    it "inherits the parent retry policy" do
      parent = create_successful_task(name: "ParentRetry") do
        retry_on CMDx::TestError, limit: 5, delay: 0
      end

      child = create_flaky_task(base: parent, name: "ChildRetry", failures: 2)

      expect(child.execute).to have_attributes(status: CMDx::Signal::SUCCESS, retries: 2)
    end

    it "merges child retry options (exceptions + limit) onto the parent's" do
      parent = create_successful_task(name: "ParentRetry2") do
        retry_on CMDx::TestError, limit: 1, delay: 0
      end

      child = create_flaky_task(base: parent, name: "ChildRetry2", failures: 2) do
        retry_on CMDx::TestError, limit: 5
      end

      expect(child.execute).to have_attributes(status: CMDx::Signal::SUCCESS, retries: 2)
    end
  end
end
