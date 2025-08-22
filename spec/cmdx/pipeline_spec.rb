# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Pipeline, type: :unit do
  let(:pipeline) { described_class.new(workflow) }
  let(:workflow_class) { class_double("WorkflowClass") }
  let(:workflow) { instance_double("WorkflowInstance", class: workflow_class) }

  describe ".execute" do
    subject(:execute) { described_class.execute(workflow) }

    it "creates a new instance and executes it" do
      expect(described_class).to receive(:new).with(workflow).and_return(pipeline)
      expect(pipeline).to receive(:execute)
      execute
    end
  end

  describe "#initialize" do
    it "sets the workflow" do
      expect(pipeline.workflow).to eq(workflow)
    end
  end

  describe "#execute" do
    let(:execution_group) { instance_double("ExecutionGroup") }
    let(:group_options) { {} }
    let(:breakpoints) { [] }

    before do
      allow(execution_group).to receive_messages(options: group_options, tasks: [])
      allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)
      allow(workflow_class).to receive_messages(pipeline: [execution_group], settings: {})
    end

    it "iterates through workflow pipeline groups" do
      expect(workflow_class).to receive(:pipeline).and_return([execution_group])
      pipeline.execute
    end

    context "when condition evaluates to true" do
      it "executes the group tasks" do
        expect(pipeline).to receive(:execute_group_tasks).with(execution_group, [])
        pipeline.execute
      end

      context "with breakpoints in group options" do
        let(:group_options) { { breakpoints: %w[step1 step2] } }

        it "uses group breakpoints" do
          expect(pipeline).to receive(:execute_group_tasks).with(execution_group, %w[step1 step2])
          pipeline.execute
        end
      end

      context "with breakpoints in workflow settings" do
        before do
          allow(workflow_class).to receive(:settings).and_return({ breakpoints: ["workflow_step"] })
        end

        it "uses workflow breakpoints" do
          expect(pipeline).to receive(:execute_group_tasks).with(execution_group, ["workflow_step"])
          pipeline.execute
        end
      end

      context "with breakpoints in workflow_breakpoints setting" do
        before do
          allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: ["wf_step"] })
        end

        it "uses workflow_breakpoints" do
          expect(pipeline).to receive(:execute_group_tasks).with(execution_group, ["wf_step"])
          pipeline.execute
        end
      end

      context "with multiple breakpoint sources" do
        let(:group_options) { { breakpoints: ["group_step"] } }

        before do
          allow(workflow_class).to receive(:settings).and_return({
            breakpoints: ["workflow_step"],
            workflow_breakpoints: ["wf_step"]
          })
        end

        it "prioritizes group breakpoints" do
          expect(pipeline).to receive(:execute_group_tasks).with(execution_group, ["group_step"])
          pipeline.execute
        end
      end

      context "with string and symbol breakpoints" do
        let(:group_options) { { breakpoints: ["step1", :step2, "step3"] } }

        it "converts all breakpoints to strings and removes duplicates" do
          expect(pipeline).to receive(:execute_group_tasks).with(execution_group, %w[step1 step2 step3])
          pipeline.execute
        end
      end
    end

    context "when condition evaluates to false" do
      before do
        allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(false)
      end

      it "skips the group tasks" do
        expect(pipeline).not_to receive(:execute_group_tasks)
        pipeline.execute
      end
    end

    context "with multiple execution groups" do
      let(:execution_group2) { instance_double("ExecutionGroup2") }
      let(:group_options2) { {} }

      before do
        allow(workflow_class).to receive(:pipeline).and_return([execution_group, execution_group2])
        allow(execution_group2).to receive_messages(options: group_options2, tasks: [])
        allow(CMDx::Utils::Condition).to receive(:evaluate).with(workflow, group_options, workflow).and_return(true)
        allow(CMDx::Utils::Condition).to receive(:evaluate).with(workflow, group_options2, workflow).and_return(true)
      end

      it "processes each group independently" do
        expect(pipeline).to receive(:execute_group_tasks).with(execution_group, [])
        expect(pipeline).to receive(:execute_group_tasks).with(execution_group2, [])
        pipeline.execute
      end
    end
  end

  describe "#execute_group_tasks" do
    let(:execution_group) { instance_double("ExecutionGroup") }
    let(:breakpoints) { [] }

    it "calls execute_tasks_sequentially with group and breakpoints" do
      expect(pipeline).to receive(:execute_tasks_sequentially).with(execution_group, breakpoints)
      pipeline.send(:execute_group_tasks, execution_group, breakpoints)
    end

    context "when overridden in subclass" do
      let(:custom_pipeline) do
        Class.new(described_class) do
          def execute_group_tasks(_group, _breakpoints)
            :custom_implementation
          end
        end
      end

      it "uses the custom implementation" do
        custom_instance = custom_pipeline.new(workflow)
        expect(custom_instance.send(:execute_group_tasks, execution_group, breakpoints)).to eq(:custom_implementation)
      end
    end
  end

  describe "#execute_tasks_sequentially" do
    let(:execution_group) { instance_double("ExecutionGroup") }
    let(:tasks) { [task1, task2, task3] }
    let(:task1) { instance_double("Task1") }
    let(:task2) { instance_double("Task2") }
    let(:task3) { instance_double("Task3") }
    let(:breakpoints) { [] }
    let(:context) { instance_double("Context") }
    let(:result1) { instance_double("Result1") }
    let(:result2) { instance_double("Result2") }
    let(:result3) { instance_double("Result3") }

    before do
      allow(workflow).to receive(:context).and_return(context)
      allow(execution_group).to receive(:tasks).and_return(tasks)
      allow(task1).to receive(:execute).with(context).and_return(result1)
      allow(task2).to receive(:execute).with(context).and_return(result2)
      allow(task3).to receive(:execute).with(context).and_return(result3)
      allow(result1).to receive(:status).and_return("success")
      allow(result2).to receive(:status).and_return("success")
      allow(result3).to receive(:status).and_return("success")
      allow(workflow).to receive(:throw!)
    end

    it "executes all tasks in sequence" do
      expect(task1).to receive(:execute).with(context).and_return(result1)
      expect(task2).to receive(:execute).with(context).and_return(result2)
      expect(task3).to receive(:execute).with(context).and_return(result3)
      pipeline.send(:execute_tasks_sequentially, execution_group, breakpoints)
    end

    context "when breakpoint is triggered on first task" do
      let(:breakpoints) { ["success"] }

      before do
        allow(result1).to receive(:status).and_return("success")
      end

      it "throws on first task but continues executing remaining tasks" do
        expect(workflow).to receive(:throw!).with(result1)
        expect(task1).to receive(:execute).with(context).and_return(result1)
        expect(task2).to receive(:execute).with(context).and_return(result2)
        expect(task3).to receive(:execute).with(context).and_return(result3)
        pipeline.send(:execute_tasks_sequentially, execution_group, breakpoints)
      end
    end

    context "when breakpoint is triggered on second task" do
      let(:breakpoints) { ["success"] }

      before do
        allow(result1).to receive(:status).and_return("failure")
        allow(result2).to receive(:status).and_return("success")
      end

      it "executes first task, then throws on second and continues with remaining tasks" do
        expect(workflow).to receive(:throw!).with(result2)
        expect(task1).to receive(:execute).with(context).and_return(result1)
        expect(task2).to receive(:execute).with(context).and_return(result2)
        expect(task3).to receive(:execute).with(context).and_return(result3)
        pipeline.send(:execute_tasks_sequentially, execution_group, breakpoints)
      end
    end

    context "with string breakpoints" do
      let(:breakpoints) { ["halt"] }

      before do
        allow(result1).to receive(:status).and_return("halt")
      end

      it "matches string breakpoints correctly" do
        expect(workflow).to receive(:throw!).with(result1)
        expect(task1).to receive(:execute).with(context).and_return(result1)
        pipeline.send(:execute_tasks_sequentially, execution_group, breakpoints)
      end
    end

    context "with symbol breakpoints" do
      let(:breakpoints) { ["halt"] }

      before do
        allow(result1).to receive(:status).and_return("halt")
      end

      it "matches symbol breakpoints correctly" do
        expect(workflow).to receive(:throw!).with(result1)
        expect(task1).to receive(:execute).with(context).and_return(result1)
        pipeline.send(:execute_tasks_sequentially, execution_group, breakpoints)
      end
    end

    context "with mixed breakpoint types" do
      let(:breakpoints) { %w[success failure] }

      before do
        allow(result1).to receive(:status).and_return("success")
      end

      it "matches both string breakpoints" do
        expect(workflow).to receive(:throw!).with(result1)
        expect(task1).to receive(:execute).with(context).and_return(result1)
        pipeline.send(:execute_tasks_sequentially, execution_group, breakpoints)
      end
    end
  end

  describe "integration scenarios" do
    let(:workflow_class) { class_double("WorkflowClass") }
    let(:workflow) { instance_double("WorkflowInstance", class: workflow_class) }
    let(:execution_group) { instance_double("ExecutionGroup") }
    let(:task) { instance_double("Task") }
    let(:context) { instance_double("Context") }
    let(:result) { instance_double("Result") }

    before do
      allow(workflow).to receive(:context).and_return(context)
      allow(task).to receive(:execute).with(context).and_return(result)
      allow(result).to receive(:status).and_return("success")
      allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)
      allow(workflow_class).to receive(:settings).and_return({})
    end

    context "when workflow has no tasks" do
      before do
        allow(workflow_class).to receive(:pipeline).and_return([])
      end

      it "executes without errors" do
        expect { pipeline.execute }.not_to raise_error
      end
    end

    context "when workflow has single task" do
      before do
        allow(execution_group).to receive_messages(options: {}, tasks: [task])
        allow(workflow_class).to receive(:pipeline).and_return([execution_group])
        allow(pipeline).to receive(:execute_group_tasks).and_call_original
        allow(pipeline).to receive(:execute_tasks_sequentially)
      end

      it "executes the single task" do
        expect(pipeline).to receive(:execute_group_tasks).with(execution_group, [])
        expect(pipeline).to receive(:execute_tasks_sequentially).with(execution_group, [])
        pipeline.execute
      end
    end

    context "when workflow has multiple task groups" do
      let(:execution_group2) { instance_double("ExecutionGroup2") }
      let(:task2) { instance_double("Task2") }

      before do
        allow(execution_group).to receive_messages(options: {}, tasks: [task])
        allow(execution_group2).to receive_messages(options: {}, tasks: [task2])
        allow(workflow_class).to receive(:pipeline).and_return([execution_group, execution_group2])
        allow(pipeline).to receive(:execute_group_tasks).and_call_original
        allow(pipeline).to receive(:execute_tasks_sequentially)
      end

      it "executes all groups" do
        expect(pipeline).to receive(:execute_group_tasks).with(execution_group, [])
        expect(pipeline).to receive(:execute_group_tasks).with(execution_group2, [])
        expect(pipeline).to receive(:execute_tasks_sequentially).with(execution_group, [])
        expect(pipeline).to receive(:execute_tasks_sequentially).with(execution_group2, [])
        pipeline.execute
      end
    end
  end
end
