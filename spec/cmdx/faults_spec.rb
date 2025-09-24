# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Fault, type: :unit do
  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:task) { task_class.new }
  let(:result) do
    task.result.tap do |r|
      r.fail!("test failure reason", halt: false)
    end
  end

  describe "#initialize" do
    subject(:fault) { described_class.new(result) }

    it "initializes with result and sets reason from result" do
      expect(fault.result).to eq(result)
      expect(fault.message).to eq("test failure reason")
    end

    it "inherits from CMDx::Error" do
      expect(fault).to be_a(CMDx::Error)
    end

    it "inherits from StandardError" do
      expect(fault).to be_a(StandardError)
    end

    context "when result has no reason" do
      let(:result) do
        task.result.tap do |r|
          r.instance_variable_set(:@reason, nil)
        end
      end

      it "initializes with nil message passed to Error" do
        expect(fault.message).to eq("CMDx::Fault")
      end
    end
  end

  describe ".for?" do
    let(:task_class_a) { create_successful_task(name: "TaskA") }
    let(:task_class_b) { create_successful_task(name: "TaskB") }
    let(:task_a) { task_class_a.new }
    let(:task_b) { task_class_b.new }
    let(:fault_a) { described_class.new(task_a.result) }
    let(:fault_b) { described_class.new(task_b.result) }

    context "when matching single task class" do
      subject(:custom_fault_class) { described_class.for?(task_class_a) }

      it "returns a new fault class" do
        expect(custom_fault_class).to be_a(Class)
        expect(custom_fault_class.superclass).to eq(described_class)
      end

      it "matches faults from specified task class" do
        allow(fault_a).to receive(:task).and_return(fault_a.result.task)
        expect(custom_fault_class === fault_a).to be(true)
      end

      it "does not match faults from other task classes" do
        allow(fault_b).to receive(:task).and_return(fault_b.result.task)
        expect(custom_fault_class === fault_b).to be(false)
      end

      it "does not match non-fault objects" do
        expect(custom_fault_class === "not a fault").to be(false)
      end

      it "stores task classes in instance variable" do
        expect(custom_fault_class.instance_variable_get(:@tasks)).to eq([task_class_a])
      end
    end

    context "when matching multiple task classes" do
      subject(:custom_fault_class) { described_class.for?(task_class_a, task_class_b) }

      it "matches faults from any specified task class" do
        allow(fault_a).to receive(:task).and_return(fault_a.result.task)
        allow(fault_b).to receive(:task).and_return(fault_b.result.task)

        expect(custom_fault_class === fault_a).to be(true)
        expect(custom_fault_class === fault_b).to be(true)
      end

      it "stores all task classes in instance variable" do
        expect(custom_fault_class.instance_variable_get(:@tasks)).to eq([task_class_a, task_class_b])
      end
    end

    context "when no task classes provided" do
      subject(:custom_fault_class) { described_class.for? }

      it "returns fault class that matches no faults" do
        allow(fault_a).to receive(:task).and_return(fault_a.result.task)
        allow(fault_b).to receive(:task).and_return(fault_b.result.task)

        expect(custom_fault_class === fault_a).to be(false)
        expect(custom_fault_class === fault_b).to be(false)
      end

      it "stores empty array in instance variable" do
        expect(custom_fault_class.instance_variable_get(:@tasks)).to eq([])
      end
    end
  end

  describe ".matches?" do
    let(:fault_with_metadata) do
      result_with_metadata = task.result.tap do |r|
        r.fail!("failure", halt: false, metadata: { error_code: 500 })
      end
      described_class.new(result_with_metadata)
    end

    context "when block is provided" do
      subject(:custom_fault_class) do
        described_class.matches? { |fault| fault.result.reason == "failure" }
      end

      it "returns a new fault class" do
        expect(custom_fault_class).to be_a(Class)
        expect(custom_fault_class.superclass).to eq(described_class)
      end

      it "matches faults that satisfy the block condition" do
        expect(custom_fault_class === fault_with_metadata).to be_truthy
      end

      it "does not match faults that don't satisfy the block condition" do
        simple_fault = described_class.new(result)
        expect(custom_fault_class === simple_fault).to be(false)
      end

      it "does not match non-fault objects" do
        expect(custom_fault_class === "not a fault").to be(false)
      end

      it "stores block in instance variable" do
        expect(custom_fault_class.instance_variable_get(:@block)).to be_a(Proc)
      end
    end

    context "when no block is provided" do
      it "raises ArgumentError" do
        expect { described_class.matches? }.to raise_error(ArgumentError, "block required")
      end
    end

    context "when block returns falsy values" do
      subject(:custom_fault_class) do
        described_class.matches? { |fault| fault.result.metadata[:nonexistent] }
      end

      it "does not match when block returns nil" do
        simple_fault = described_class.new(result)
        expect(custom_fault_class === simple_fault).to be_falsy
      end

      it "does not match when block returns false" do
        custom_false_class = described_class.matches? { |_| false }
        simple_fault = described_class.new(result)
        expect(custom_false_class === simple_fault).to be_falsy
      end
    end

    context "when block returns truthy values" do
      it "matches when block returns true" do
        custom_true_class = described_class.matches? { |_| true }
        simple_fault = described_class.new(result)
        expect(custom_true_class === simple_fault).to be_truthy
      end

      it "matches when block returns truthy object" do
        custom_truthy_class = described_class.matches? { |_| "truthy" }
        simple_fault = described_class.new(result)
        expect(custom_truthy_class === simple_fault).to be_truthy
      end
    end
  end

  describe "task accessor" do
    subject(:fault) { described_class.new(result) }

    it "provides access to task through result" do
      expect(fault.result.task).to eq(task)
    end
  end
end
