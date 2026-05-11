# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Deprecation do
  let(:logger) { Logger.new(log_output) }
  let(:log_output) { StringIO.new }
  let(:task) do
    log = logger
    Class.new do
      define_method(:logger) { log }
      def active? = true
      def inactive? = false
      def custom_handler = @handler_called = true
      attr_reader :handler_called
    end.new
  end

  def run(value, **opts)
    yielded = false
    described_class.new(value, opts).execute(task) { yielded = true }
    yielded
  end

  describe "#execute" do
    it "is a no-op when value is nil" do
      expect(run(nil)).to be(false)
    end

    it "skips when the if-guard is false" do
      expect(run(:log, if: :inactive?)).to be(false)
    end

    it "skips when the unless-guard is true" do
      expect(run(:log, unless: :active?)).to be(false)
    end

    it "runs the provided block before dispatching" do
      expect(run(:log)).to be(true)
    end

    context "with :log" do
      it "logs a warning via the task's logger" do
        run(:log)
        expect(log_output.string).to include("DEPRECATED:", task.class.to_s)
      end
    end

    context "with :warn" do
      it "writes a warning to Kernel.warn" do
        expect { run(:warn) }.to output(/DEPRECATED: migrate/).to_stderr
      end
    end

    context "with :error" do
      it "raises DeprecationError" do
        expect { run(:error) }.to raise_error(CMDx::DeprecationError, /is deprecated and prohibited from execution/)
      end
    end

    context "with a Symbol" do
      it "sends the method on the task" do
        run(:custom_handler)
        expect(task.handler_called).to be(true)
      end
    end

    context "with a Proc" do
      it "evaluates the proc via instance_exec and passes the task" do
        received = nil
        probe = proc { |t| received = [self, t] }
        described_class.new(probe).execute(task) { nil }

        expect(received).to eq([task, task])
      end
    end

    context "with a callable object" do
      it "invokes #call with the task" do
        callable = Class.new do
          class << self

            attr_reader :received

            def call(task) = @received = task

          end
        end
        described_class.new(callable).execute(task) { nil }

        expect(callable.received).to be(task)
      end
    end

    context "with an unsupported value" do
      it "raises ArgumentError" do
        expect { described_class.new(123).execute(task) { nil } }
          .to raise_error(ArgumentError, /deprecation must be a Symbol, Proc, or respond to #call/)
      end
    end
  end
end
