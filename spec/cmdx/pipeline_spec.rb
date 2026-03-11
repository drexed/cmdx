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
      allow(workflow_class).to receive_messages(pipeline: [execution_group], settings: mock_settings(workflow_breakpoints: []))
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
          allow(workflow_class).to receive(:settings).and_return(mock_settings(breakpoints: ["workflow_step"]))
        end

        it "uses workflow breakpoints" do
          expect(pipeline).to receive(:execute_group_tasks).with(execution_group, ["workflow_step"])
          pipeline.execute
        end
      end

      context "with breakpoints in workflow_breakpoints setting" do
        before do
          allow(workflow_class).to receive(:settings).and_return(mock_settings(workflow_breakpoints: ["wf_step"]))
        end

        it "uses workflow_breakpoints" do
          expect(pipeline).to receive(:execute_group_tasks).with(execution_group, ["wf_step"])
          pipeline.execute
        end
      end

      context "with multiple breakpoint sources" do
        let(:group_options) { { breakpoints: ["group_step"] } }

        before do
          allow(workflow_class).to receive(:settings).and_return(
            mock_settings(breakpoints: ["workflow_step"], workflow_breakpoints: ["wf_step"])
          )
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

    context "when strategy is nil" do
      before do
        allow(execution_group).to receive(:options).and_return({})
      end

      it "calls execute_tasks_in_sequence" do
        expect(pipeline).to receive(:execute_tasks_in_sequence).with(execution_group, breakpoints)
        pipeline.send(:execute_group_tasks, execution_group, breakpoints)
      end
    end

    context "when strategy is sequential" do
      before do
        allow(execution_group).to receive(:options).and_return({ strategy: :sequential })
      end

      it "calls execute_tasks_in_sequence" do
        expect(pipeline).to receive(:execute_tasks_in_sequence).with(execution_group, breakpoints)
        pipeline.send(:execute_group_tasks, execution_group, breakpoints)
      end
    end

    context "when strategy is parallel" do
      before do
        allow(execution_group).to receive(:options).and_return({ strategy: :parallel })
      end

      it "calls execute_tasks_in_parallel" do
        expect(pipeline).to receive(:execute_tasks_in_parallel).with(execution_group, breakpoints)
        pipeline.send(:execute_group_tasks, execution_group, breakpoints)
      end
    end

    context "when strategy is unknown" do
      before do
        allow(execution_group).to receive(:options).and_return({ strategy: :unknown })
      end

      it "raises an error" do
        expect { pipeline.send(:execute_group_tasks, execution_group, breakpoints) }
          .to raise_error("unknown execution strategy :unknown")
      end
    end
  end

  describe "#execute_tasks_in_sequence" do
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
      pipeline.send(:execute_tasks_in_sequence, execution_group, breakpoints)
    end

    context "when breakpoint is triggered on first task" do
      let(:breakpoints) { ["success"] }

      before do
        allow(result1).to receive(:status).and_return("success")
      end

      it "throws on first task and continues executing remaining tasks" do
        expect(workflow).to receive(:throw!).with(result1)
        expect(task1).to receive(:execute).with(context).and_return(result1)
        expect(task2).to receive(:execute).with(context).and_return(result2)
        expect(task3).to receive(:execute).with(context).and_return(result3)
        pipeline.send(:execute_tasks_in_sequence, execution_group, breakpoints)
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
        pipeline.send(:execute_tasks_in_sequence, execution_group, breakpoints)
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
        pipeline.send(:execute_tasks_in_sequence, execution_group, breakpoints)
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
        pipeline.send(:execute_tasks_in_sequence, execution_group, breakpoints)
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
        pipeline.send(:execute_tasks_in_sequence, execution_group, breakpoints)
      end
    end
  end

  describe "#execute_tasks_in_parallel" do
    let(:execution_group) { instance_double("ExecutionGroup") }
    let(:tasks) { [task1, task2, task3] }
    let(:task1) { instance_double("Task1") }
    let(:task2) { instance_double("Task2") }
    let(:task3) { instance_double("Task3") }
    let(:breakpoints) { [] }
    let(:context) { CMDx::Context.new(user_id: 1) }
    let(:result1) { instance_double("Result1") }
    let(:result2) { instance_double("Result2") }
    let(:result3) { instance_double("Result3") }
    let(:chain) { instance_double("Chain") }
    let(:result_hash) { { status: "failed" } }

    before do
      allow(workflow).to receive_messages(context: context, chain: chain)
      allow(execution_group).to receive_messages(tasks: tasks, options: {})
      allow(task1).to receive(:execute).and_return(result1)
      allow(task2).to receive(:execute).and_return(result2)
      allow(task3).to receive(:execute).and_return(result3)
      allow(result1).to receive_messages(status: "success", to_h: result_hash)
      allow(result2).to receive_messages(status: "success", to_h: result_hash)
      allow(result3).to receive_messages(status: "success", to_h: result_hash)
      allow(CMDx::Chain).to receive(:current=)
    end

    it "creates context snapshots for each task" do
      expect(task1).to receive(:execute) do |ctx|
        expect(ctx).to be_a(CMDx::Context)
        expect(ctx.to_h).to eq(user_id: 1)
        expect(ctx).not_to equal(context)
        result1
      end
      pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
    end

    it "executes all tasks via Parallelizer" do
      expect(task1).to receive(:execute).and_return(result1)
      expect(task2).to receive(:execute).and_return(result2)
      expect(task3).to receive(:execute).and_return(result3)
      pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
    end

    it "merges context snapshots back into workflow context" do
      expect(workflow.context).to receive(:merge!).exactly(3).times
      pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
    end

    it "sets Chain.current for each thread" do
      expect(CMDx::Chain).to receive(:current=).with(chain).at_least(3).times
      pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
    end

    context "when breakpoint is triggered" do
      let(:breakpoints) { ["failed"] }

      before do
        allow(result2).to receive(:status).and_return("failed")
        allow(workflow).to receive(:failed!)
      end

      it "calls the faulted status method on the workflow" do
        expect(workflow).to receive(:failed!).with(
          CMDx::Locale.t("cmdx.faults.unspecified"),
          source: :parallel,
          faults: [result_hash]
        )
        pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
      end
    end

    context "when multiple breakpoints are triggered" do
      let(:breakpoints) { %w[failed skipped] }

      before do
        allow(result1).to receive(:status).and_return("skipped")
        allow(result3).to receive(:status).and_return("failed")
        allow(workflow).to receive(:failed!)
      end

      it "uses the last faulted result status and includes all faulted results" do
        expect(workflow).to receive(:failed!).with(
          CMDx::Locale.t("cmdx.faults.unspecified"),
          source: :parallel,
          faults: [result_hash, result_hash]
        )
        pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
      end
    end

    context "when no breakpoints are triggered" do
      let(:breakpoints) { ["failed"] }

      it "does not call any fault method on the workflow" do
        expect(workflow).not_to receive(:failed!)
        pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
      end
    end
  end
end
