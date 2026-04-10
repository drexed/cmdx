# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Resolver, type: :unit do
  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:task) { task_class.new }
  let(:result) { task.result }
  let(:resolver) { task.resolver }

  describe "#initialize" do
    context "with valid result" do
      it "initializes with correct defaults" do
        expect(resolver.result).to eq(result)
        expect(result.strict?).to be(true)
      end
    end

    context "with invalid result" do
      it "raises TypeError when result is not a CMDx::Result" do
        expect { described_class.new("not a result") }.to raise_error(TypeError, "must be a CMDx::Result")
      end
    end
  end

  describe "#success!" do
    context "when successful" do
      it "sets the reason" do
        catch(:cmdx_halt) { resolver.success!("Created 42 records") }

        expect(result.status).to eq(CMDx::Result::SUCCESS)
        expect(result.reason).to eq("Created 42 records")
        expect(result.metadata).to eq({})
      end

      it "accepts metadata" do
        catch(:cmdx_halt) { resolver.success!("Imported", rows: 100) }

        expect(result.reason).to eq("Imported")
        expect(result.metadata).to eq({ rows: 100 })
      end

      it "allows nil reason" do
        catch(:cmdx_halt) { resolver.success! }

        expect(result.reason).to be_nil
      end

      it "does not change state or status" do
        original_state = result.state
        original_status = result.status
        catch(:cmdx_halt) { resolver.success!("note") }

        expect(result.state).to eq(original_state)
        expect(result.status).to eq(original_status)
      end

      it "throws :cmdx_halt by default" do
        expect { resolver.success!("done") }.to throw_symbol(:cmdx_halt)
      end

      it "does not throw when halt is false" do
        expect { resolver.success!("done", halt: false) }.not_to throw_symbol(:cmdx_halt)
      end
    end

    context "when not successful" do
      it "raises error when skipped" do
        resolver.skip!("test", halt: false)

        expect { resolver.success!("reason") }.to raise_error(/can only be used while success/)
      end

      it "raises error when failed" do
        resolver.fail!("test", halt: false)

        expect { resolver.success!("reason") }.to raise_error(/can only be used while success/)
      end
    end
  end

  describe "#skip!" do
    context "when successful" do
      it "transitions to skipped status" do
        resolver.skip!("test reason", halt: false)

        expect(result.status).to eq(CMDx::Result::SKIPPED)
        expect(result.state).to eq(CMDx::Result::INTERRUPTED)
        expect(result.reason).to eq("test reason")
        expect(result.cause).to be_nil
        expect(result.metadata).to eq({})
      end

      it "accepts metadata" do
        resolver.skip!("test reason", halt: false, foo: "bar")

        expect(result.metadata).to eq({ foo: "bar" })
      end

      it "accepts cause" do
        cause = StandardError.new("cause")
        resolver.skip!("test reason", halt: false, cause: cause)

        expect(result.cause).to eq(cause)
      end

      it "uses default reason when none provided" do
        allow(CMDx::Locale).to receive(:t).with("cmdx.reasons.unspecified").and_return("Unspecified")

        resolver.skip!(halt: false)

        expect(result.reason).to eq("Unspecified")
      end

      it "calls halt! by default" do
        expect { resolver.skip!("test reason") }.to raise_error(CMDx::SkipFault)
      end

      it "does not call halt! when halt: false" do
        expect { resolver.skip!("test reason", halt: false) }.not_to raise_error
      end
    end

    context "when already skipped" do
      it "returns early without changes" do
        resolver.skip!("first reason", halt: false)
        original_reason = result.reason
        resolver.skip!("second reason", halt: false)

        expect(result.reason).to eq(original_reason)
      end
    end

    context "when not successful" do
      it "raises error when trying to skip from failed" do
        resolver.fail!("test reason", halt: false)

        expect { resolver.skip!("another reason", halt: false) }.to raise_error(/can only transition to skipped from success/)
      end
    end
  end

  describe "#fail!" do
    context "when successful" do
      it "transitions to failed status" do
        resolver.fail!("test reason", halt: false)

        expect(result.status).to eq(CMDx::Result::FAILED)
        expect(result.state).to eq(CMDx::Result::INTERRUPTED)
        expect(result.reason).to eq("test reason")
        expect(result.cause).to be_nil
        expect(result.metadata).to eq({})
      end

      it "accepts metadata" do
        resolver.fail!("test reason", halt: false, foo: "bar")

        expect(result.metadata).to eq({ foo: "bar" })
      end

      it "accepts cause" do
        cause = StandardError.new("cause")
        resolver.fail!("test reason", halt: false, cause: cause)

        expect(result.cause).to eq(cause)
      end

      it "uses default reason when none provided" do
        allow(CMDx::Locale).to receive(:t).with("cmdx.reasons.unspecified").and_return("Unspecified")

        resolver.fail!(halt: false)

        expect(result.reason).to eq("Unspecified")
      end

      it "calls halt! by default" do
        expect { resolver.fail!("test reason") }.to raise_error(CMDx::FailFault)
      end

      it "does not call halt! when halt: false" do
        expect { resolver.fail!("test reason", halt: false) }.not_to raise_error
      end
    end

    context "when already failed" do
      it "returns early without changes" do
        resolver.fail!("first reason", halt: false)
        original_reason = result.reason
        resolver.fail!("second reason", halt: false)

        expect(result.reason).to eq(original_reason)
      end
    end

    context "when not successful" do
      it "raises error when trying to fail from skipped" do
        resolver.skip!("test reason", halt: false)

        expect { resolver.fail!("another reason", halt: false) }.to raise_error(/can only transition to failed from success/)
      end
    end
  end

  describe "#halt!" do
    context "when successful" do
      it "returns early without raising" do
        expect { resolver.halt! }.not_to raise_error
      end
    end

    context "when skipped" do
      it "raises SkipFault" do
        resolver.skip!("test reason", halt: false)

        expect { resolver.halt! }.to raise_error(CMDx::SkipFault) do |fault|
          expect(fault.result).to eq(result)
          expect(fault.message).to eq("test reason")
        end
      end

      it "sets proper backtrace" do
        resolver.skip!("test reason", halt: false)

        begin
          resolver.halt!
        rescue CMDx::SkipFault => e
          expect(e.backtrace).to be_an(Array)
          expect(e.backtrace).not_to be_empty
        end
      end
    end

    context "when failed" do
      it "raises FailFault" do
        resolver.fail!("test reason", halt: false)

        expect { resolver.halt! }.to raise_error(CMDx::FailFault) do |fault|
          expect(fault.result).to eq(result)
          expect(fault.message).to eq("test reason")
        end
      end
    end
  end

  describe "#throw!" do
    let(:other_task) { create_failing_task.new }
    let(:other_result) { other_task.result }

    before do
      other_task.resolver.fail!("source failure", halt: false, foo: "bar")
    end

    context "with valid result" do
      it "copies state and status from other result" do
        resolver.throw!(other_result, halt: false)

        expect(result.state).to eq(other_result.state)
        expect(result.status).to eq(other_result.status)
        expect(result.reason).to eq(other_result.reason)
      end

      it "merges metadata" do
        resolver.throw!(other_result, halt: false, baz: "qux")

        expect(result.metadata).to eq({ foo: "bar", baz: "qux" })
      end

      it "uses provided cause over other result's cause" do
        custom_cause = StandardError.new("custom")

        resolver.throw!(other_result, halt: false, cause: custom_cause)
        expect(result.cause).to eq(custom_cause)
      end

      it "uses other result's cause when none provided" do
        other_cause = StandardError.new("other")
        other_result.instance_variable_set(:@cause, other_cause)
        resolver.throw!(other_result, halt: false)

        expect(result.cause).to eq(other_cause)
      end

      it "calls halt! by default" do
        expect { resolver.throw!(other_result) }.to raise_error(CMDx::FailFault)
      end

      it "does not call halt! when halt: false" do
        expect { resolver.throw!(other_result, halt: false) }.not_to raise_error
      end
    end

    context "with invalid result" do
      it "raises TypeError when not a CMDx::Result" do
        expect { resolver.throw!("not a result", halt: false) }.to raise_error(TypeError, "must be a CMDx::Result")
      end
    end
  end

  describe "#strict?" do
    it "returns true by default" do
      expect(result.strict?).to be(true)
    end

    it "returns false when strict is false via fail!" do
      resolver.fail!("test reason", halt: false, strict: false)

      expect(result.strict?).to be(false)
    end

    it "returns false when strict is false via skip!" do
      resolver.skip!("test reason", halt: false, strict: false)

      expect(result.strict?).to be(false)
    end
  end
end
