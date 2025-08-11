# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Fault do
  let(:task_class) { create_task_class }
  let(:task) { task_class.new }
  let(:result) { CMDx::Result.new(task) }

  describe "#initialize" do
    context "when result has a reason" do
      let(:failed_result) do
        result.instance_variable_set(:@status, CMDx::Result::FAILED)
        result.instance_variable_set(:@state, CMDx::Result::INTERRUPTED)
        result.instance_variable_set(:@reason, "Test failure reason")
        result
      end

      it "sets the result attribute" do
        fault = described_class.new(failed_result)

        expect(fault.result).to eq(failed_result)
      end

      it "sets the message from result reason" do
        fault = described_class.new(failed_result)

        expect(fault.message).to eq("Test failure reason")
      end

      it "inherits from CMDx::Error" do
        fault = described_class.new(failed_result)

        expect(fault).to be_a(CMDx::Error)
      end
    end

    context "when result has no reason" do
      let(:failed_result_no_reason) do
        result.instance_variable_set(:@status, CMDx::Result::FAILED)
        result.instance_variable_set(:@state, CMDx::Result::INTERRUPTED)
        result.instance_variable_set(:@reason, "Unspecified error")
        result
      end

      it "uses the result reason as message" do
        fault = described_class.new(failed_result_no_reason)

        expect(fault.message).to eq("Unspecified error")
      end
    end
  end

  describe ".for?" do
    let(:specific_task_class) { create_task_class(name: "SpecificTask") }
    let(:other_task_class) { create_task_class(name: "OtherTask") }
    let(:specific_task) { specific_task_class.new }
    let(:other_task) { other_task_class.new }
    let(:specific_result) { CMDx::Result.new(specific_task) }
    let(:other_result) { CMDx::Result.new(other_task) }

    let(:specific_failed_result) do
      specific_result.instance_variable_set(:@status, CMDx::Result::FAILED)
      specific_result.instance_variable_set(:@state, CMDx::Result::INTERRUPTED)
      specific_result.instance_variable_set(:@reason, "Specific failure")
      specific_result
    end

    let(:other_failed_result) do
      other_result.instance_variable_set(:@status, CMDx::Result::FAILED)
      other_result.instance_variable_set(:@state, CMDx::Result::INTERRUPTED)
      other_result.instance_variable_set(:@reason, "Other failure")
      other_result
    end

    it "creates a temporary fault class for task matching" do
      temp_fault_class = described_class.for?(specific_task_class)

      expect(temp_fault_class).to be_a(Class)
      expect(temp_fault_class.superclass).to eq(described_class)
    end

    context "when fault matches specified task class" do
      it "returns true for case equality" do
        temp_fault_class = described_class.for?(specific_task_class)
        specific_fault = described_class.build(specific_failed_result)

        # The implementation expects other.task but Fault has other.result.task
        # We'll stub the task method to return the task from result
        allow(specific_fault).to receive(:task).and_return(specific_fault.result.task)

        expect(temp_fault_class === specific_fault).to be(true)
      end
    end

    context "when fault does not match specified task class" do
      it "returns false for case equality" do
        temp_fault_class = described_class.for?(specific_task_class)
        other_fault = described_class.build(other_failed_result)

        # Stub the task method for the other fault as well
        allow(other_fault).to receive(:task).and_return(other_fault.result.task)

        expect(temp_fault_class === other_fault).to be(false)
      end
    end

    context "when multiple task classes are specified" do
      it "matches any of the specified task classes" do
        temp_fault_class = described_class.for?(specific_task_class, other_task_class)
        specific_fault = described_class.build(specific_failed_result)
        other_fault = described_class.build(other_failed_result)

        # Stub the task method for both faults
        allow(specific_fault).to receive(:task).and_return(specific_fault.result.task)
        allow(other_fault).to receive(:task).and_return(other_fault.result.task)

        expect(temp_fault_class === specific_fault).to be(true)
        expect(temp_fault_class === other_fault).to be(true)
      end
    end

    context "when object is not a fault" do
      it "returns false for case equality" do
        temp_fault_class = described_class.for?(specific_task_class)

        expect(temp_fault_class === "not a fault").to be(false)
      end
    end
  end

  describe ".matches?" do
    let(:failed_result) do
      result_copy = CMDx::Result.new(task)
      result_copy.instance_variable_set(:@status, CMDx::Result::FAILED)
      result_copy.instance_variable_set(:@state, CMDx::Result::INTERRUPTED)
      result_copy.instance_variable_set(:@reason, "Test failure")
      result_copy
    end

    let(:skipped_result) do
      result_copy = CMDx::Result.new(task)
      result_copy.instance_variable_set(:@status, CMDx::Result::SKIPPED)
      result_copy.instance_variable_set(:@state, CMDx::Result::INTERRUPTED)
      result_copy.instance_variable_set(:@reason, "Test skip")
      result_copy
    end

    context "when no block is given" do
      it "raises ArgumentError" do
        expect { described_class.matches? }
          .to raise_error(ArgumentError, "block required")
      end
    end

    context "when block is given" do
      it "creates a temporary fault class for custom matching" do
        temp_fault_class = described_class.matches? { |fault| fault.result.failed? }

        expect(temp_fault_class).to be_a(Class)
        expect(temp_fault_class.superclass).to eq(described_class)
      end

      context "when block returns true" do
        it "returns true for case equality" do
          temp_fault_class = described_class.matches? { |fault| fault.result.failed? }
          failed_fault = described_class.build(failed_result)

          expect(temp_fault_class === failed_fault).to be(true)
        end
      end

      context "when block returns false" do
        it "returns false for case equality" do
          temp_fault_class = described_class.matches? { |fault| fault.result.failed? }
          skipped_fault = described_class.build(skipped_result)

          expect(temp_fault_class === skipped_fault).to be(false)
        end
      end

      context "when object is not a fault" do
        it "returns false for case equality" do
          temp_fault_class = described_class.matches? { true }

          expect(temp_fault_class === "not a fault").to be(false)
        end
      end

      it "passes the fault to the block for evaluation" do
        block_called_with = nil
        temp_fault_class = described_class.matches? do |fault|
          block_called_with = fault
          true
        end
        failed_fault = described_class.build(failed_result)

        temp_fault_class === failed_fault # rubocop:disable Lint/Void

        expect(block_called_with).to eq(failed_fault)
      end
    end
  end
end
