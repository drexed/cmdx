# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Fault do
  let(:chain) { CMDx::Chain.new }
  let(:task_class) { create_task_class(name: "SampleTask") }
  let(:task) { task_class.new }

  def build_result(signal, klass: task_class, **opts)
    instance = klass.new
    CMDx::Result.new(chain, instance, signal, **opts)
  end

  describe "#initialize" do
    let(:signal) { CMDx::Signal.failed("boom") }
    let(:result) { build_result(signal) }

    it "stores the result and exposes task/signal/context/chain" do
      fault = described_class.new(result)

      expect(fault).to have_attributes(
        result:,
        task: task_class,
        context: result.context,
        chain:
      )
    end

    it "uses the signal's reason as the message" do
      expect(described_class.new(result).message).to eq("boom")
    end

    it "falls back to a localized unspecified message when reason is nil" do
      result_without_reason = build_result(CMDx::Signal.failed)

      expect(described_class.new(result_without_reason).message)
        .to eq(CMDx::I18nProxy.t("cmdx.reasons.unspecified"))
    end

    it "resolves the reason through I18nProxy when a translation key matches" do
      allow(CMDx::I18nProxy).to receive(:tr).with("boom").and_return("Translated boom")
      expect(described_class.new(result).message).to eq("Translated boom")
    end

    it "descends from CMDx::Error" do
      expect(described_class.new(result)).to be_a(CMDx::Error)
    end
  end

  describe "backtrace handling" do
    context "when the signal carries a backtrace" do
      it "applies it to the fault" do
        frames = %w[a.rb:1 b.rb:2]
        result = build_result(CMDx::Signal.failed("b", backtrace: frames))

        expect(described_class.new(result).backtrace).to eq(frames)
      end
    end

    context "when the signal has a cause with backtrace_locations" do
      it "uses the cause's backtrace" do
        cause =
          begin
            raise StandardError, "inner"
          rescue StandardError => e
            e
          end
        result = build_result(CMDx::Signal.failed("b", cause:))

        expect(described_class.new(result).backtrace).to eq(cause.backtrace_locations.map(&:to_s))
      end
    end

    context "when neither backtrace source is present" do
      it "leaves backtrace nil" do
        expect(described_class.new(build_result(CMDx::Signal.failed("b"))).backtrace).to be_nil
      end
    end

    context "with a backtrace_cleaner configured on task settings" do
      it "runs the cleaner over the frames" do
        task_class.settings(backtrace_cleaner: ->(frames) { frames.map { |f| "cleaned:#{f}" } })
        result = build_result(CMDx::Signal.failed("b", backtrace: %w[a b]))

        expect(described_class.new(result).backtrace).to eq(%w[cleaned:a cleaned:b])
      end

      it "keeps the original frames when the cleaner returns a falsy value" do
        task_class.settings(backtrace_cleaner: ->(_frames) {})
        result = build_result(CMDx::Signal.failed("b", backtrace: %w[a b]))

        expect(described_class.new(result).backtrace).to eq(%w[a b])
      end
    end
  end

  describe ".for?" do
    let(:parent_task) { create_task_class(name: "ParentTask") }
    let(:child_task) { create_task_class(base: parent_task, name: "ChildTask") }
    let(:other_task) { create_task_class(name: "OtherTask") }
    let(:signal) { CMDx::Signal.failed("boom") }

    it "raises when called with no tasks" do
      expect { described_class.for? }.to raise_error(ArgumentError, /Fault\.for\? requires at least one Task class/)
    end

    it "matches faults whose task is <= one of the given tasks" do
      matcher = described_class.for?(parent_task)
      fault_child = described_class.new(build_result(signal, klass: child_task))
      fault_other = described_class.new(build_result(signal, klass: other_task))

      expect(matcher === fault_child).to be(true)
      expect(matcher === fault_other).to be(false)
    end

    it "accepts a flat array of tasks" do
      matcher = described_class.for?([parent_task, other_task])
      expect(matcher === described_class.new(build_result(signal, klass: other_task))).to be(true)
    end

    it "only matches instances of the class that defined it" do
      subclass = Class.new(described_class)
      matcher = subclass.for?(parent_task)

      parent_fault = described_class.new(build_result(signal, klass: parent_task))

      expect(matcher === parent_fault).to be(false)
    end
  end

  describe ".reason?" do
    let(:signal) { CMDx::Signal.failed("boom") }

    it "raises when called without a reason" do
      expect { described_class.reason?(nil) }.to raise_error(ArgumentError, /Fault\.reason\? requires a reason/)
    end

    it "matches faults whose result reason equals the given reason" do
      matcher = described_class.reason?("boom")
      expect(matcher === described_class.new(build_result(signal))).to be(true)
    end

    it "does not match faults with a different reason" do
      matcher = described_class.reason?("other")
      expect(matcher === described_class.new(build_result(signal))).to be(false)
    end

    it "only matches instances of the class that defined it" do
      subclass = Class.new(described_class)
      matcher = subclass.reason?("boom")

      expect(matcher === described_class.new(build_result(signal))).to be(false)
    end

    it "does not match non-Fault objects" do
      matcher = described_class.reason?("boom")
      expect(matcher === "not a fault").to be(false)
    end
  end

  describe ".matches?" do
    let(:signal) { CMDx::Signal.failed("boom") }
    let(:result) { build_result(signal) }

    it "raises when called without a block" do
      expect { described_class.matches? }.to raise_error(ArgumentError, /Fault\.matches\? requires a block/)
    end

    it "matches when both the class check and the block return truthy" do
      matcher = described_class.matches? { |f| f.result.reason == "boom" }
      fault = described_class.new(result)

      expect(matcher === fault).to be(true)
    end

    it "does not match when the block returns false" do
      matcher = described_class.matches? { |_f| false }
      fault = described_class.new(result)

      expect(matcher === fault).to be(false)
    end

    it "does not match non-Fault objects" do
      matcher = described_class.matches? { true }
      expect(matcher === "not a fault").to be(false)
    end
  end
end
