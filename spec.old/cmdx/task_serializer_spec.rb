# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::TaskSerializer do
  describe ".call" do
    let(:task_class) { create_simple_task(name: "TestTask") }
    let(:task) { task_class.new }
    let(:chain) { instance_double(CMDx::Chain, id: "chain_123") }
    let(:result) { instance_double(CMDx::Result, index: 2) }

    before do
      allow(task).to receive_messages(chain: chain, result: result, id: "task_456")
      allow(task).to receive(:cmd_setting).with(:tags).and_return(%i[user validation])
    end

    context "with task object" do
      it "returns serialized task hash" do
        serialized = described_class.call(task)

        expect(serialized).to include(
          index: 2,
          chain_id: "chain_123",
          type: "Task",
          id: "task_456",
          tags: %i[user validation]
        )
        expect(serialized[:class]).to start_with("TestTask")
      end

      it "extracts index from task result" do
        serialized = described_class.call(task)

        expect(serialized[:index]).to eq(2)
      end

      it "extracts chain_id from task chain" do
        serialized = described_class.call(task)

        expect(serialized[:chain_id]).to eq("chain_123")
      end

      it "uses class name for class field" do
        serialized = described_class.call(task)

        expect(serialized[:class]).to start_with("TestTask")
      end

      it "extracts id from task" do
        serialized = described_class.call(task)

        expect(serialized[:id]).to eq("task_456")
      end

      it "extracts tags from cmd_setting" do
        serialized = described_class.call(task)

        expect(serialized[:tags]).to eq(%i[user validation])
      end
    end

    context "with workflow object" do
      let(:workflow_class) { create_simple_workflow(name: "TestWorkflow", tasks: [task_class]) }
      let(:workflow) { workflow_class.new }

      before do
        allow(workflow).to receive_messages(chain: chain, result: result, id: "workflow_789")
        allow(workflow).to receive(:cmd_setting).with(:tags).and_return(%i[process orchestration])
      end

      it "returns type as Workflow" do
        serialized = described_class.call(workflow)

        expect(serialized[:type]).to eq("Workflow")
      end

      it "serializes workflow with all expected fields" do
        serialized = described_class.call(workflow)

        expect(serialized).to include(
          index: 2,
          chain_id: "chain_123",
          type: "Workflow",
          id: "workflow_789",
          tags: %i[process orchestration]
        )
        expect(serialized[:class]).to start_with("TestWorkflow")
      end
    end

    context "when task execution" do
      let(:executed_task_class) do
        create_task_class(name: "RealExecutionTask") do
          required :input, type: :string

          def call
            context.processed = "processed_#{input}"
          end
        end
      end

      it "serializes executed task" do
        result = executed_task_class.call(input: "test")

        serialized = described_class.call(result.task)

        expect(serialized).to include(
          type: "Task"
        )
        expect(serialized[:class]).to start_with("RealExecutionTask")
        expect(serialized[:index]).to be_a(Integer)
        expect(serialized[:chain_id]).to be_a(String)
        expect(serialized[:id]).to be_a(String)
        expect(serialized[:tags]).to be_an(Array)
      end
    end

    context "when workflow execution" do
      let(:step_task_class) { create_simple_task(name: "StepTask") }
      let(:executed_workflow_class) do
        create_simple_workflow(name: "RealExecutionWorkflow", tasks: [step_task_class])
      end

      it "serializes executed workflow" do
        result = executed_workflow_class.call

        serialized = described_class.call(result.task)

        expect(serialized).to include(
          type: "Workflow"
        )
        expect(serialized[:class]).to start_with("RealExecutionWorkflow")
        expect(serialized[:index]).to be_a(Integer)
        expect(serialized[:chain_id]).to be_a(String)
        expect(serialized[:id]).to be_a(String)
        expect(serialized[:tags]).to be_an(Array)
      end
    end

    context "with empty tags" do
      before do
        allow(task).to receive(:cmd_setting).with(:tags).and_return([])
      end

      it "returns empty array for tags" do
        serialized = described_class.call(task)

        expect(serialized[:tags]).to eq([])
      end
    end

    context "with nil tags" do
      before do
        allow(task).to receive(:cmd_setting).with(:tags).and_return(nil)
      end

      it "returns nil for tags" do
        serialized = described_class.call(task)

        expect(serialized[:tags]).to be_nil
      end
    end

    context "when task lacks required methods" do
      let(:incomplete_task) { Object.new }

      it "raises NoMethodError for missing result method" do
        expect { described_class.call(incomplete_task) }.to raise_error(
          NoMethodError,
          /undefined method.*result/
        )
      end
    end

    context "when result lacks index method" do
      let(:incomplete_result) { Object.new }

      before do
        allow(task).to receive(:result).and_return(incomplete_result)
      end

      it "raises NoMethodError for missing index method" do
        expect { described_class.call(task) }.to raise_error(
          NoMethodError,
          /undefined method.*index/
        )
      end
    end

    context "when chain lacks id method" do
      let(:incomplete_chain) { Object.new }

      before do
        allow(task).to receive(:chain).and_return(incomplete_chain)
      end

      it "raises NoMethodError for missing id method" do
        expect { described_class.call(task) }.to raise_error(
          NoMethodError,
          /undefined method.*id/
        )
      end
    end

    context "when task lacks cmd_setting method" do
      let(:task_without_cmd_setting) { Object.new }

      before do
        allow(task_without_cmd_setting).to receive_messages(result: result, chain: chain, id: "task_456", class: double(name: "TestTask"))
      end

      it "raises NoMethodError for missing cmd_setting method" do
        expect { described_class.call(task_without_cmd_setting) }.to raise_error(
          NoMethodError,
          /undefined method.*cmd_setting/
        )
      end
    end
  end
end
