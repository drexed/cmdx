# frozen_string_literal: true

RSpec.describe CMDx::Retry do
  let(:error_class) { Class.new(StandardError) }

  describe "#initialize" do
    it "flattens the exceptions argument" do
      retry_ = described_class.new([[error_class]])
      expect(retry_.exceptions).to eq([error_class])
    end
  end

  describe "#build" do
    it "returns self when no additional exceptions are given" do
      retry_ = described_class.new([error_class])
      expect(retry_.build([], {})).to be(retry_)
    end

    it "unions exceptions and merges options" do
      other_error = Class.new(StandardError)
      retry_ = described_class.new([error_class], limit: 1)
      rebuilt = retry_.build([other_error], limit: 5)

      expect(rebuilt.exceptions).to contain_exactly(error_class, other_error)
      expect(rebuilt.limit).to eq(5)
    end

    it "preserves the original block when no new block is given" do
      original_block = proc { :orig }
      retry_ = described_class.new([error_class], {}, &original_block)
      rebuilt = retry_.build([Class.new(StandardError)], {})

      expect(rebuilt.jitter).to be(original_block)
    end

    it "replaces the block when a new one is given" do
      new_block = proc { :new }
      retry_ = described_class.new([error_class], {}) { :orig }
      rebuilt = retry_.build([Class.new(StandardError)], {}, &new_block)

      expect(rebuilt.jitter).to be(new_block)
    end
  end

  describe "default options" do
    subject(:retry_) { described_class.new([error_class]) }

    it "limit defaults to 3" do
      expect(retry_.limit).to eq(3)
    end

    it "delay defaults to 0.5" do
      expect(retry_.delay).to eq(0.5)
    end

    it "max_delay defaults to nil" do
      expect(retry_.max_delay).to be_nil
    end

    it "jitter defaults to nil" do
      expect(retry_.jitter).to be_nil
    end
  end

  describe "#jitter" do
    it "returns the block when no :jitter option is set" do
      block = proc { :j }
      retry_ = described_class.new([error_class], {}, &block)
      expect(retry_.jitter).to be(block)
    end

    it "prefers the :jitter option over the block" do
      block = proc { :b }
      retry_ = described_class.new([error_class], { jitter: :exponential }, &block)
      expect(retry_.jitter).to eq(:exponential)
    end
  end

  describe "#wait" do
    let(:sleeps) { [] }

    before do
      s = sleeps
      allow(Kernel).to receive(:sleep) { |d| s << d }
    end

    it "does nothing when delay is zero" do
      described_class.new([error_class], delay: 0).wait(1)
      expect(sleeps).to be_empty
    end

    it "sleeps for the configured delay with no jitter" do
      described_class.new([error_class], delay: 0.25).wait(2)
      expect(sleeps).to eq([0.25])
    end

    it "computes exponential backoff" do
      described_class.new([error_class], delay: 0.25, jitter: :exponential).wait(3)
      expect(sleeps).to eq([0.25 * (2**3)])
    end

    it "clamps to max_delay" do
      described_class.new([error_class], delay: 0.25, jitter: :exponential, max_delay: 1.0).wait(5)
      expect(sleeps).to eq([1.0])
    end

    it "linear produces delay * (attempt + 1)" do
      described_class.new([error_class], delay: 0.25, jitter: :linear).wait(3)
      expect(sleeps).to eq([1.0])
    end

    it "fibonacci produces delay * fib(attempt + 1) across attempts" do
      retry_ = described_class.new([error_class], delay: 1.0, jitter: :fibonacci)
      6.times { |i| retry_.wait(i) }
      expect(sleeps).to eq([1.0, 1.0, 2.0, 3.0, 5.0, 8.0])
    end

    it "decorrelated_jitter threads prev_delay through wait's third argument" do
      allow(CMDx::Retriers::DecorrelatedJitter).to receive(:rand).and_return(1.0)
      retry_ = described_class.new([error_class], delay: 1.0, jitter: :decorrelated_jitter)

      retry_.wait(0, nil, 4.0)
      expect(sleeps).to eq([12.0])
    end

    it "wait returns the computed delay so process can thread it" do
      allow(CMDx::Retriers::DecorrelatedJitter).to receive(:rand).and_return(0.5)
      retry_ = described_class.new([error_class], delay: 1.0, jitter: :decorrelated_jitter)

      expect(retry_.wait(0)).to eq(2.0)
    end

    it "delegates Symbol jitter to the retriers registry" do
      strategy = ->(attempt, delay, _prev) { delay * (attempt + 10) }
      task_class = Class.new
      task_class.singleton_class.define_method(:retriers) do
        @retriers ||= CMDx::Retriers.new.tap { |r| r.register(:custom, strategy) }
      end
      task = task_class.new

      described_class.new([error_class], delay: 1.0, jitter: :custom).wait(2, task)
      expect(sleeps).to eq([12.0])
    end

    it "falls back to a task instance method when Symbol is not in the registry" do
      task = Class.new { def jitter_calc(attempt, delay) = delay * attempt }.new
      described_class.new([error_class], delay: 1.0, jitter: :jitter_calc).wait(4, task)

      expect(sleeps).to eq([4.0])
    end

    it "evaluates a Proc jitter via instance_exec on the task" do
      retry_ = described_class.new([error_class], delay: 1.0) { |attempt, delay| attempt + delay }
      retry_.wait(2, Object.new)

      expect(sleeps).to eq([3.0])
    end

    it "calls a callable jitter" do
      callable = ->(attempt, delay) { attempt + delay + 1 }
      described_class.new([error_class], delay: 1.0, jitter: callable).wait(1)

      expect(sleeps).to eq([3.0])
    end
  end

  describe "#process" do
    it "yields once with attempt 0 when there are no exceptions" do
      retry_ = described_class.new([])
      attempts = []
      retry_.process { |attempt| attempts << attempt }
      expect(attempts).to eq([0])
    end

    it "yields once when limit is zero" do
      retry_ = described_class.new([error_class], limit: 0)
      attempts = []
      retry_.process { |a| attempts << a }
      expect(attempts).to eq([0])
    end

    it "retries up to the limit on matching exceptions" do
      retry_ = described_class.new([error_class], limit: 2, delay: 0)
      count = 0

      retry_.process do |_attempt|
        count += 1
        raise error_class, "boom" if count < 3
      end

      expect(count).to eq(3)
    end

    it "re-raises after the limit is exceeded" do
      retry_ = described_class.new([error_class], limit: 1, delay: 0)

      expect { retry_.process { raise error_class, "boom" } }
        .to raise_error(error_class, "boom")
    end

    it "does not rescue non-matching exceptions" do
      retry_ = described_class.new([error_class], limit: 3, delay: 0)

      expect { retry_.process { raise "other" } }
        .to raise_error(RuntimeError, "other")
    end

    it "threads prev_delay across attempts for :decorrelated_jitter" do
      sleeps = []
      allow(Kernel).to receive(:sleep) { |d| sleeps << d }
      allow(CMDx::Retriers::DecorrelatedJitter).to receive(:rand).and_return(1.0)

      retry_ = described_class.new([error_class], limit: 3, delay: 1.0, jitter: :decorrelated_jitter)

      attempts = 0
      expect do
        retry_.process do
          attempts += 1
          raise error_class, "boom"
        end
      end.to raise_error(error_class)

      expect(sleeps).to eq([3.0, 9.0, 27.0])
      expect(attempts).to eq(4)
    end

    it "passes the attempt number to the block" do
      retry_ = described_class.new([error_class], limit: 2, delay: 0)
      attempts = []

      retry_.process do |attempt|
        attempts << attempt
        raise error_class if attempts.size < 3
      end

      expect(attempts).to eq([0, 1, 2])
    end

    context "with :if/:unless gates" do
      let(:task) do
        Class.new do
          attr_accessor :seen_attempts, :seen_errors

          def initialize
            @seen_attempts = []
            @seen_errors = []
          end

          def transient?(error, attempt)
            @seen_errors << error
            @seen_attempts << attempt
            error.message != "permanent"
          end
        end.new
      end

      it "stops retrying when :if returns false" do
        retry_ = described_class.new([error_class], limit: 5, delay: 0, if: :transient?)
        count = 0

        expect do
          retry_.process(task) do |_attempt|
            count += 1
            raise error_class, "permanent"
          end
        end.to raise_error(error_class, "permanent")

        expect(count).to eq(1)
        expect(task.seen_attempts).to eq([0])
      end

      it "still retries while :if returns true" do
        retry_ = described_class.new([error_class], limit: 3, delay: 0, if: :transient?)
        attempts = 0

        retry_.process(task) do |_attempt|
          attempts += 1
          raise(error_class, "transient") if attempts < 3
        end

        expect(attempts).to eq(3)
      end

      it "stops retrying when :unless is truthy" do
        retry_ = described_class.new([error_class], limit: 3, delay: 0, unless: proc { |e, _a| e.message == "stop" })

        expect do
          retry_.process(Object.new) { raise error_class, "stop" }
        end.to raise_error(error_class, "stop")
      end
    end
  end
end
