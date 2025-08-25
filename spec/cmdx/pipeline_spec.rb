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
    let(:context) { instance_double("Context") }
    let(:result1) { instance_double("Result1") }
    let(:result2) { instance_double("Result2") }
    let(:result3) { instance_double("Result3") }
    let(:chain) { instance_double("Chain") }

    before do
      allow(workflow).to receive_messages(context: context, chain: chain)
      allow(execution_group).to receive_messages(tasks: tasks, options: {})
      allow(task1).to receive(:execute).with(context).and_return(result1)
      allow(task2).to receive(:execute).with(context).and_return(result2)
      allow(task3).to receive(:execute).with(context).and_return(result3)
      allow(result1).to receive(:status).and_return("success")
      allow(result2).to receive(:status).and_return("success")
      allow(result3).to receive(:status).and_return("success")
      allow(workflow).to receive(:throw!)
      allow(CMDx::Chain).to receive(:current=)
    end

    context "when parallel gem is not available" do
      before do
        hide_const("Parallel")
      end

      it "raises an error" do
        expect { pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints) }
          .to raise_error("install the `parallel` gem to use this feature")
      end
    end

    context "when parallel gem is available" do
      let(:parallel_double) { class_double("Parallel") }

      before do
        stub_const("Parallel", parallel_double)
        allow(parallel_double).to receive(:each)
      end

      it "executes all tasks in parallel" do
        expect(parallel_double).to receive(:each).with(tasks)
        pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
      end

      context "with in_threads option" do
        before do
          allow(execution_group).to receive(:options).and_return({ in_threads: 4 })
        end

        it "passes in_threads to parallel" do
          expect(parallel_double).to receive(:each).with(tasks, { in_threads: 4 })
          pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
        end
      end

      context "with in_processes option" do
        before do
          allow(execution_group).to receive(:options).and_return({ in_processes: 2 })
        end

        it "passes in_processes to parallel" do
          expect(parallel_double).to receive(:each).with(tasks, { in_processes: 2 })
          pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
        end
      end

      context "with both parallel options" do
        before do
          allow(execution_group).to receive(:options).and_return({ in_threads: 4, in_processes: 2 })
        end

        it "passes both options to parallel" do
          expect(parallel_double).to receive(:each).with(tasks, { in_threads: 4, in_processes: 2 })
          pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
        end
      end

      context "when breakpoint is triggered" do
        let(:breakpoints) { ["failure"] }
        let(:parallel_break_error) { Class.new(StandardError) }

        before do
          stub_const("Parallel::Break", parallel_break_error)
          allow(parallel_double).to receive(:each).and_raise(parallel_break_error, result1)
        end

        it "raises Parallel::Break when parallel execution fails" do
          expect { pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints) }
            .to raise_error(parallel_break_error)
        end
      end

      context "when no breakpoints are triggered" do
        let(:breakpoints) { ["failure"] }

        before do
          allow(parallel_double).to receive(:each)
        end

        it "does not throw the workflow" do
          expect(workflow).not_to receive(:throw!)
          pipeline.send(:execute_tasks_in_parallel, execution_group, breakpoints)
        end
      end
    end
  end
end
