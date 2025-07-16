# frozen_string_literal: true

require "spec_helper"

# rubocop:disable Style/CaseEquality
RSpec.describe CMDx::Fault do
  let(:task_class) { create_simple_task(name: "TestTask") }
  let(:failed_result) do
    result = task_class.call
    result.instance_variable_set(:@status, "failed")
    result.instance_variable_set(:@state, "interrupted")
    result.metadata[:reason] = "Test failure"
    result
  end
  let(:skipped_result) do
    result = task_class.call
    result.instance_variable_set(:@status, "skipped")
    result.instance_variable_set(:@state, "interrupted")
    result.metadata[:reason] = "Test skip"
    result
  end
  let(:result_without_reason) do
    result = task_class.call
    result.instance_variable_set(:@status, "failed")
    result.instance_variable_set(:@state, "interrupted")
    result
  end

  describe "#initialize" do
    subject(:fault) { described_class.new(failed_result) }

    it "sets the result" do
      expect(fault.result).to eq(failed_result)
    end

    it "uses the reason from result metadata as message" do
      expect(fault.message).to eq("Test failure")
    end

    context "when result has no reason in metadata" do
      subject(:fault) { described_class.new(result_without_reason) }

      it "falls back to default i18n message" do
        expect(fault.message).to eq("no reason given")
      end
    end
  end

  describe "delegation" do
    subject(:fault) { described_class.new(failed_result) }

    it "delegates task to result" do
      expect(fault.task).to eq(failed_result.task)
    end

    it "delegates chain to result" do
      expect(fault.chain).to eq(failed_result.chain)
    end

    it "delegates context to result" do
      expect(fault.context).to eq(failed_result.context)
    end
  end

  describe ".build" do
    it "creates Failed fault for failed result" do
      fault = described_class.build(failed_result)

      expect(fault).to be_a(CMDx::Failed)
      expect(fault.result).to eq(failed_result)
    end

    it "creates Skipped fault for skipped result" do
      fault = described_class.build(skipped_result)

      expect(fault).to be_a(CMDx::Skipped)
      expect(fault.result).to eq(skipped_result)
    end

    it "raises error for unknown status" do
      allow(failed_result).to receive(:status).and_return("unknown")

      expect { described_class.build(failed_result) }.to raise_error(NameError)
    end
  end

  describe ".for?" do
    let(:user_task_class) { create_failing_task(name: "UserTask") }
    let(:order_task_class) { create_failing_task(name: "OrderTask") }
    let(:other_task_class) { create_failing_task(name: "OtherTask") }
    let(:user_fault) do
      result = user_task_class.call
      result.instance_variable_set(:@status, "failed")
      described_class.new(result)
    end
    let(:order_fault) do
      result = order_task_class.call
      result.instance_variable_set(:@status, "failed")
      described_class.new(result)
    end
    let(:other_fault) do
      result = other_task_class.call
      result.instance_variable_set(:@status, "failed")
      described_class.new(result)
    end

    it "creates matcher that matches faults from specified task classes" do
      matcher = described_class.for?(user_task_class, order_task_class)

      expect(matcher === user_fault).to be(true)
      expect(matcher === order_fault).to be(true)
      expect(matcher === other_fault).to be(false)
    end

    it "works in rescue clauses" do
      rescued_fault = nil

      begin
        raise user_fault
      rescue described_class.for?(user_task_class) => e
        rescued_fault = e
      end

      expect(rescued_fault).to eq(user_fault)
    end

    it "doesn't match non-fault exceptions" do
      matcher = described_class.for?(user_task_class)
      standard_error = StandardError.new("test")

      expect(matcher === standard_error).to be(false)
    end

    it "handles multiple task classes" do
      matcher = described_class.for?(user_task_class, order_task_class, task_class)

      expect(matcher === user_fault).to be(true)
      expect(matcher === order_fault).to be(true)
      expect(matcher === other_fault).to be(false)
    end
  end

  describe ".matches?" do
    let(:user_task_class) { create_failing_task(name: "UserTask") }
    let(:user_fault) do
      result = user_task_class.call(user_id: 123)
      result.instance_variable_set(:@status, "failed")
      described_class.new(result)
    end
    let(:other_fault) do
      result = task_class.call
      result.instance_variable_set(:@status, "failed")
      described_class.new(result)
    end

    it "creates matcher based on block condition" do
      matcher = described_class.matches? { |f| f.context.user_id == 123 }

      expect(matcher === user_fault).to be(true)
      expect(matcher === other_fault).to be(false)
    end

    it "works in rescue clauses" do
      rescued_fault = nil

      begin
        raise user_fault
      rescue described_class.matches? { |f| f.context.user_id == 123 } => e
        rescued_fault = e
      end

      expect(rescued_fault).to eq(user_fault)
    end

    it "doesn't match non-fault exceptions" do
      matcher = described_class.matches? { |f| f.context.user_id == 123 }
      standard_error = StandardError.new("test")

      expect(matcher === standard_error).to be(false)
    end

    it "raises ArgumentError when no block is given" do
      expect { described_class.matches? }.to raise_error(ArgumentError, "block required")
    end

    context "with complex conditions" do
      let(:complex_task_class) do
        create_failing_task(name: "ComplexTask") do
          required :category, type: :string
          required :priority, type: :integer
        end
      end
      let(:complex_fault) do
        result = complex_task_class.call(category: "urgent", priority: 1)
        result.instance_variable_set(:@status, "failed")
        described_class.new(result)
      end

      it "matches complex block conditions" do
        matcher = described_class.matches? do |f|
          f.context.category == "urgent" && f.context.priority < 5
        end

        expect(matcher === complex_fault).to be(true)
      end
    end
  end

  describe "inheritance" do
    it "inherits from CMDx::Error" do
      expect(described_class.superclass).to eq(CMDx::Error)
    end

    it "is raised as exception" do
      fault = described_class.new(failed_result)

      expect { raise fault }.to raise_error(described_class)
    end
  end

  describe "integration with task execution" do
    context "with call! method" do
      let(:failing_task_class) { create_failing_task(reason: "Integration test failure") }

      it "raises appropriate fault when task fails" do
        expect { failing_task_class.call! }.to raise_error(CMDx::Failed) do |fault|
          expect(fault.message).to eq("Integration test failure")
          expect(fault.task).to be_a(failing_task_class)
          expect(fault.result).to be_failed_task
        end
      end
    end
  end

  describe "fault subclasses" do
    describe CMDx::Failed do
      let(:failed_fault) { CMDx::Failed.new(failed_result) } # rubocop:disable RSpec/DescribedClass

      it "is a fault" do
        expect(failed_fault).to be_a(described_class)
      end

      it "has the correct result" do
        expect(failed_fault.result).to eq(failed_result)
      end
    end

    describe CMDx::Skipped do
      let(:skipped_fault) { CMDx::Skipped.new(skipped_result) } # rubocop:disable RSpec/DescribedClass

      it "is a fault" do
        expect(skipped_fault).to be_a(described_class)
      end

      it "has the correct result" do
        expect(skipped_fault.result).to eq(skipped_result)
      end
    end
  end
end
# rubocop:enable Style/CaseEquality
