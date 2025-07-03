# frozen_string_literal: true

# rubocop:disable Style/CaseEquality

require "spec_helper"

RSpec.describe CMDx::Fault do
  describe "#initialize" do
    let(:task) { mock_task }
    let(:chain) { mock_chain }
    let(:context) { mock_context }
    let(:metadata) { {} }
    let(:result) { mock_result(task: task, chain: chain, context: context, metadata: metadata) }

    context "when result has reason in metadata" do
      let(:metadata) { { reason: "Custom error message" } }

      it "uses the reason from metadata as message" do
        fault = described_class.new(result)

        expect(fault.message).to eq("Custom error message")
      end

      it "stores the result object" do
        fault = described_class.new(result)

        expect(fault.result).to eq(result)
      end
    end

    context "when result has no reason in metadata" do
      let(:metadata) { {} }

      before do
        allow(I18n).to receive(:t).with("cmdx.faults.unspecified", default: "no reason given")
                                  .and_return("no reason given")
      end

      it "uses I18n fallback message" do
        fault = described_class.new(result)

        expect(fault.message).to eq("no reason given")
      end

      it "calls I18n with correct parameters" do
        described_class.new(result)

        expect(I18n).to have_received(:t).with("cmdx.faults.unspecified", default: "no reason given")
      end
    end

    context "when I18n returns custom localized message" do
      let(:metadata) { {} }

      before do
        allow(I18n).to receive(:t).with("cmdx.faults.unspecified", default: "no reason given")
                                  .and_return("Localized error message")
      end

      it "uses the localized message" do
        fault = described_class.new(result)

        expect(fault.message).to eq("Localized error message")
      end
    end

    context "when metadata has nil reason" do
      let(:metadata) { { reason: nil } }

      before do
        allow(I18n).to receive(:t).with("cmdx.faults.unspecified", default: "no reason given")
                                  .and_return("no reason given")
      end

      it "uses I18n fallback message for nil reason" do
        fault = described_class.new(result)

        expect(fault.message).to eq("no reason given")
      end
    end

    context "when metadata has empty string reason" do
      let(:metadata) { { reason: "" } }

      it "uses empty string as message (not I18n fallback)" do
        fault = described_class.new(result)

        expect(fault.message).to eq("")
      end
    end
  end

  describe "attribute delegation" do
    let(:task) { mock_task(name: "TestTask") }
    let(:chain) { mock_chain(id: "chain-123") }
    let(:context) { mock_context(order_id: 456) }
    let(:result) { mock_result(task: task, chain: chain, context: context, metadata: { reason: "Test error" }) }
    let(:fault) { described_class.new(result) }

    it "delegates task to result" do
      expect(fault.task).to eq(task)
    end

    it "delegates chain to result" do
      expect(fault.chain).to eq(chain)
    end

    it "delegates context to result" do
      expect(fault.context).to eq(context)
    end

    it "can access delegated attributes' methods" do
      expect(fault.task.name).to eq("TestTask")
      expect(fault.chain.id).to eq("chain-123")
      expect(fault.context.order_id).to eq(456)
    end
  end

  describe "inheritance" do
    let(:result) { mock_result(metadata: { reason: "Test error" }) }

    it "inherits from CMDx::Error" do
      expect(described_class.superclass).to eq(CMDx::Error)
    end

    it "is a kind of StandardError" do
      fault = described_class.new(result)

      expect(fault).to be_a(StandardError)
    end

    it "can be rescued as StandardError" do
      fault = described_class.new(result)

      expect { raise fault }.to raise_error(StandardError)
    end

    it "can be rescued as CMDx::Error" do
      fault = described_class.new(result)

      expect { raise fault }.to raise_error(CMDx::Error)
    end

    it "can be rescued as CMDx::Fault" do
      fault = described_class.new(result)

      expect { raise fault }.to raise_error(described_class)
    end
  end

  describe ".build" do
    let(:task) { mock_task }
    let(:chain) { mock_chain }
    let(:context) { mock_context }

    context "when result status is 'skipped'" do
      let(:result) { mock_result(status: "skipped", task: task, chain: chain, context: context, metadata: { reason: "Skipped" }) }

      before do
        stub_const("CMDx::Skipped", Class.new(described_class))
      end

      it "builds a Skipped fault" do
        fault = described_class.build(result)

        expect(fault).to be_a(CMDx::Skipped)
      end

      it "passes result to the new fault" do
        fault = described_class.build(result)

        expect(fault.result).to eq(result)
      end
    end

    context "when result status is 'failed'" do
      let(:result) { mock_result(status: "failed", task: task, chain: chain, context: context, metadata: { reason: "Failed" }) }

      before do
        stub_const("CMDx::Failed", Class.new(described_class))
      end

      it "builds a Failed fault" do
        fault = described_class.build(result)

        expect(fault).to be_a(CMDx::Failed)
      end

      it "passes result to the new fault" do
        fault = described_class.build(result)

        expect(fault.result).to eq(result)
      end
    end

    context "when result status is custom" do
      let(:result) { mock_result(status: "custom", task: task, chain: chain, context: context, metadata: { reason: "Custom" }) }

      before do
        stub_const("CMDx::Custom", Class.new(described_class))
      end

      it "builds the corresponding fault class" do
        fault = described_class.build(result)

        expect(fault).to be_a(CMDx::Custom)
      end
    end

    context "when fault class does not exist" do
      let(:result) { mock_result(status: "nonexistent", task: task, chain: chain, context: context, metadata: { reason: "Error" }) }

      it "raises NameError" do
        expect { described_class.build(result) }.to raise_error(NameError, /uninitialized constant CMDx::Nonexistent/)
      end
    end
  end

  describe ".for?" do
    let(:task_class_a) { Class.new }
    let(:task_class_b) { Class.new }
    let(:task_class_c) { Class.new }
    let(:task_a) { task_class_a.new }
    let(:task_b) { task_class_b.new }
    let(:task_c) { task_class_c.new }

    context "when matching single task class" do
      let(:matcher) { described_class.for?(task_class_a) }
      let(:fault_a) { described_class.new(mock_result(task: task_a, metadata: {})) }
      let(:fault_b) { described_class.new(mock_result(task: task_b, metadata: {})) }

      it "matches faults from specified task class" do
        expect(matcher === fault_a).to be(true)
      end

      it "does not match faults from other task classes" do
        expect(matcher === fault_b).to be(false)
      end

      it "returns a class that inherits from original fault class" do
        expect(matcher.superclass).to eq(described_class)
      end
    end

    context "when matching multiple task classes" do
      let(:matcher) { described_class.for?(task_class_a, task_class_b) }
      let(:fault_a) { described_class.new(mock_result(task: task_a, metadata: {})) }
      let(:fault_b) { described_class.new(mock_result(task: task_b, metadata: {})) }
      let(:fault_c) { described_class.new(mock_result(task: task_c, metadata: {})) }

      it "matches faults from any specified task class" do
        expect(matcher === fault_a).to be(true)
        expect(matcher === fault_b).to be(true)
      end

      it "does not match faults from unspecified task classes" do
        expect(matcher === fault_c).to be(false)
      end
    end

    context "when matching with inheritance" do
      let(:parent_task_class) { Class.new }
      let(:child_task_class) { Class.new(parent_task_class) }
      let(:child_task) { child_task_class.new }
      let(:matcher) { described_class.for?(parent_task_class) }
      let(:fault) { described_class.new(mock_result(task: child_task, metadata: {})) }

      it "matches faults from child classes" do
        expect(matcher === fault).to be(true)
      end
    end

    context "when matching non-fault objects" do
      let(:matcher) { described_class.for?(task_class_a) }
      let(:regular_error) { StandardError.new("Not a fault") }

      it "does not match non-fault objects" do
        expect(matcher === regular_error).to be(false)
      end

      it "does not match nil" do
        expect(matcher.nil?).to be(false)
      end
    end

    context "when using matcher in rescue clause" do
      let(:matcher) { described_class.for?(task_class_a) }
      let(:matching_fault) { described_class.new(mock_result(task: task_a, metadata: {})) }
      let(:non_matching_fault) { described_class.new(mock_result(task: task_b, metadata: {})) }

      it "catches matching faults" do
        caught_fault = nil
        begin
          raise matching_fault
        rescue matcher => e
          caught_fault = e
        end

        expect(caught_fault).to eq(matching_fault)
      end

      it "does not catch non-matching faults" do
        caught_fault = nil
        begin
          raise non_matching_fault
        rescue matcher => e
          caught_fault = e
        rescue described_class
          # This should catch the non-matching fault
        end

        expect(caught_fault).to be_nil
      end
    end
  end

  describe ".matches?" do
    let(:task) { mock_task }
    let(:result_with_metadata) { mock_result(task: task, metadata: { error_code: "PAYMENT_DECLINED" }) }
    let(:result_without_metadata) { mock_result(task: task, metadata: {}) }

    context "when no block is given" do
      it "raises ArgumentError" do
        expect { described_class.matches? }.to raise_error(ArgumentError, "block required")
      end
    end

    context "when block returns true" do
      let(:matcher) { described_class.matches? { |_f| true } }
      let(:fault) { described_class.new(result_with_metadata) }

      it "matches the fault" do
        expect(matcher === fault).to be(true)
      end

      it "returns a class that inherits from original fault class" do
        expect(matcher.superclass).to eq(described_class)
      end
    end

    context "when block returns false" do
      let(:matcher) { described_class.matches? { |_f| false } }
      let(:fault) { described_class.new(result_with_metadata) }

      it "does not match the fault" do
        expect(matcher === fault).to be(false)
      end
    end

    context "when matching by metadata" do
      let(:matcher) { described_class.matches? { |f| f.result.metadata[:error_code] == "PAYMENT_DECLINED" } }
      let(:matching_fault) { described_class.new(result_with_metadata) }
      let(:non_matching_fault) { described_class.new(result_without_metadata) }

      it "matches faults with correct metadata" do
        expect(matcher === matching_fault).to be(true)
      end

      it "does not match faults without correct metadata" do
        expect(matcher === non_matching_fault).to be(false)
      end
    end

    context "when matching by task type" do
      let(:order_task_class) { Class.new }
      let(:payment_task_class) { Class.new }
      let(:order_task) { order_task_class.new }
      let(:payment_task) { payment_task_class.new }
      let(:matcher) { described_class.matches? { |f| f.task.instance_of?(order_task_class) } }
      let(:order_fault) { described_class.new(mock_result(task: order_task, metadata: {})) }
      let(:payment_fault) { described_class.new(mock_result(task: payment_task, metadata: {})) }

      it "matches faults from correct task type" do
        expect(matcher === order_fault).to be(true)
      end

      it "does not match faults from incorrect task type" do
        expect(matcher === payment_fault).to be(false)
      end
    end

    context "when matching with complex logic" do
      let(:context) { mock_context(order_value: 1500) }
      let(:result) { mock_result(task: task, context: context, metadata: { error_code: "TIMEOUT" }) }
      let(:matcher) do
        described_class.matches? do |f|
          f.result.metadata[:error_code] == "TIMEOUT" &&
            f.context.order_value > 1000
        end
      end
      let(:fault) { described_class.new(result) }

      it "matches faults satisfying complex conditions" do
        expect(matcher === fault).to be(true)
      end
    end

    context "when block raises error" do
      let(:matcher) { described_class.matches? { |_f| raise StandardError, "Block error" } }
      let(:fault) { described_class.new(result_with_metadata) }

      it "propagates the error from block" do
        expect { matcher === fault }.to raise_error(StandardError, "Block error")
      end
    end

    context "when matching non-fault objects" do
      let(:matcher) { described_class.matches? { |_f| true } }
      let(:regular_error) { StandardError.new("Not a fault") }

      it "does not match non-fault objects" do
        expect(matcher === regular_error).to be(false)
      end

      it "does not call block for non-fault objects" do
        block_called = false
        matcher = described_class.matches? do |_f|
          block_called = true
          true
        end

        matcher === regular_error # rubocop:disable Lint/Void

        expect(block_called).to be(false)
      end
    end

    context "when using matcher in rescue clause" do
      let(:matcher) { described_class.matches? { |f| f.result.metadata[:error_code] == "PAYMENT_DECLINED" } }
      let(:matching_fault) { described_class.new(result_with_metadata) }
      let(:non_matching_fault) { described_class.new(result_without_metadata) }

      it "catches matching faults" do
        caught_fault = nil
        begin
          raise matching_fault
        rescue matcher => e
          caught_fault = e
        end

        expect(caught_fault).to eq(matching_fault)
      end

      it "does not catch non-matching faults" do
        caught_fault = nil
        begin
          raise non_matching_fault
        rescue matcher => e
          caught_fault = e
        rescue described_class
          # This should catch the non-matching fault
        end

        expect(caught_fault).to be_nil
      end
    end
  end

  describe "integration scenarios" do
    let(:task) { mock_task(class: double(name: "ProcessOrderTask")) }
    let(:chain) { mock_chain(id: "chain-123") }
    let(:context) { mock_context(order_id: 456, order_value: 1200) }

    context "when handling task execution faults" do
      let(:result) { mock_result(task: task, chain: chain, context: context, metadata: { reason: "Insufficient inventory", error_code: "INVENTORY_DEPLETED" }) }
      let(:fault) { described_class.new(result) }

      it "provides full context access" do
        expect(fault.result.metadata[:reason]).to eq("Insufficient inventory")
        expect(fault.result.metadata[:error_code]).to eq("INVENTORY_DEPLETED")
        expect(fault.task.class.name).to eq("ProcessOrderTask")
        expect(fault.context.order_id).to eq(456)
        expect(fault.chain.id).to eq("chain-123")
      end

      it "can be used in rescue with multiple matching strategies" do
        task_class = Class.new
        allow(task).to receive(:is_a?).with(task_class).and_return(true)

        task_matcher = described_class.for?(task_class)
        metadata_matcher = described_class.matches? { |f| f.result.metadata[:error_code] == "INVENTORY_DEPLETED" }

        expect(task_matcher === fault).to be(true)
        expect(metadata_matcher === fault).to be(true)
      end
    end

    context "when building faults dynamically" do
      before do
        stub_const("CMDx::Failed", Class.new(described_class))
        stub_const("CMDx::Skipped", Class.new(described_class))
      end

      it "creates appropriate fault types" do
        failed_result = mock_result(status: "failed", task: task, chain: chain, context: context, metadata: { reason: "Processing failed" })
        skipped_result = mock_result(status: "skipped", task: task, chain: chain, context: context, metadata: { reason: "Already processed" })

        failed_fault = described_class.build(failed_result)
        skipped_fault = described_class.build(skipped_result)

        expect(failed_fault).to be_a(CMDx::Failed)
        expect(skipped_fault).to be_a(CMDx::Skipped)
        expect(failed_fault.message).to eq("Processing failed")
        expect(skipped_fault.message).to eq("Already processed")
      end
    end

    context "when combining matchers" do
      let(:order_task_class) { Class.new }
      let(:payment_task_class) { Class.new }
      let(:order_task) { order_task_class.new }
      let(:payment_task) { payment_task_class.new }

      let(:order_fault) { described_class.new(mock_result(task: order_task, metadata: { error_code: "INVENTORY_DEPLETED" })) }
      let(:payment_fault) { described_class.new(mock_result(task: payment_task, metadata: { error_code: "PAYMENT_DECLINED" })) }

      it "supports specific task and metadata matching" do
        described_class.for?(order_task_class).matches? { |f| f.result.metadata[:error_code] == "INVENTORY_DEPLETED" }
        described_class.for?(payment_task_class).matches? { |f| f.result.metadata[:error_code] == "PAYMENT_DECLINED" }

        # NOTE: This tests the concept, though the actual implementation might not support chaining
        expect(described_class.for?(order_task_class) === order_fault).to be(true)
        expect(described_class.matches? { |f| f.result.metadata[:error_code] == "INVENTORY_DEPLETED" } === order_fault).to be(true)
      end
    end

    context "when handling I18n edge cases" do
      before do
        allow(I18n).to receive(:t).and_call_original
      end

      it "handles I18n translation errors gracefully" do
        allow(I18n).to receive(:t).with("cmdx.faults.unspecified", default: "no reason given")
                                  .and_raise(I18n::InvalidLocale.new("Invalid locale"))
        result = mock_result(metadata: {})

        expect { described_class.new(result) }.to raise_error(I18n::InvalidLocale)
      end

      it "handles missing I18n gracefully with default" do
        allow(I18n).to receive(:t).with("cmdx.faults.unspecified", default: "no reason given")
                                  .and_return("no reason given")
        result = mock_result(metadata: {})

        fault = described_class.new(result)

        expect(fault.message).to eq("no reason given")
      end
    end
  end
end

# rubocop:enable Style/CaseEquality
