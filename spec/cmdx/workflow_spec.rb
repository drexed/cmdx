# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Workflow do
  let(:context_data) { { user_id: 123, action: "test" } }

  describe "inheritance" do
    it "inherits from Task" do
      expect(described_class.superclass).to eq(CMDx::Task)
    end
  end

  describe "Group struct" do
    let(:tasks) { [create_simple_task] }
    let(:options) { { workflow_halt: :failed } }
    let(:group) { described_class::Group.new(tasks, options) }

    it "holds tasks and options" do
      expect(group.tasks).to eq(tasks)
      expect(group.options).to eq(options)
    end
  end

  describe ".workflow_groups" do
    let(:workflow_class) { create_workflow_class }

    it "returns empty array by default" do
      expect(workflow_class.workflow_groups).to eq([])
    end

    it "maintains workflow groups state" do
      task = create_simple_task
      workflow_class.process task

      expect(workflow_class.workflow_groups.size).to eq(1)
      expect(workflow_class.workflow_groups.first.tasks).to eq([task])
    end
  end

  describe ".process" do
    let(:workflow_class) { create_workflow_class }
    let(:task_one) { create_simple_task(name: "Task1") }
    let(:task_two) { create_simple_task(name: "Task2") }

    context "with single task" do
      it "creates group with one task" do
        workflow_class.process task_one

        expect(workflow_class.workflow_groups.size).to eq(1)
        expect(workflow_class.workflow_groups.first.tasks).to eq([task_one])
        expect(workflow_class.workflow_groups.first.options).to eq({})
      end
    end

    context "with multiple tasks" do
      it "creates group with multiple tasks" do
        workflow_class.process task_one, task_two

        expect(workflow_class.workflow_groups.size).to eq(1)
        expect(workflow_class.workflow_groups.first.tasks).to eq([task_one, task_two])
      end
    end

    context "with flattened array of tasks" do
      it "flattens task arrays" do
        workflow_class.process [task_one, task_two]

        expect(workflow_class.workflow_groups.size).to eq(1)
        expect(workflow_class.workflow_groups.first.tasks).to eq([task_one, task_two])
      end
    end

    context "with options" do
      it "stores options in group" do
        options = { workflow_halt: :failed, if: -> { true } }
        workflow_class.process task_one, **options

        expect(workflow_class.workflow_groups.first.options).to eq(options)
      end
    end

    context "with invalid task" do
      it "raises TypeError for non-Task class" do
        expect { workflow_class.process String }.to raise_error(TypeError, "must be a Task or Workflow")
      end

      it "raises TypeError for regular object" do
        expect { workflow_class.process "not a task" }.to raise_error(TypeError, "must be a Task or Workflow")
      end
    end

    context "with multiple process calls" do
      it "creates multiple groups" do
        workflow_class.process task_one
        workflow_class.process task_two

        expect(workflow_class.workflow_groups.size).to eq(2)
        expect(workflow_class.workflow_groups[0].tasks).to eq([task_one])
        expect(workflow_class.workflow_groups[1].tasks).to eq([task_two])
      end
    end
  end

  describe "#call" do
    context "with successful tasks" do
      let(:workflow_class) do
        task_one = create_simple_task(name: "Task1")
        task_two = create_simple_task(name: "Task2")

        create_workflow_class do
          process task_one
          process task_two
        end
      end

      it "executes all tasks successfully" do
        result = workflow_class.call(context_data)

        expect(result).to be_success
        expect(result.context.executed).to be(true)
      end

      it "preserves context across tasks" do
        result = workflow_class.call(context_data)

        expect(result.context.user_id).to eq(123)
        expect(result.context.action).to eq("test")
      end
    end

    context "with failing task" do
      let(:workflow_class) do
        before_task = create_simple_task(name: "BeforeTask")
        failing_task = create_failing_task(name: "FailingTask", reason: "Validation failed")
        after_task = create_simple_task(name: "AfterTask")

        create_workflow_class do
          process before_task
          process failing_task
          process after_task
        end
      end

      it "halts on failed task by default" do
        result = workflow_class.call(context_data)

        expect(result).to be_failed
        expect(result.metadata[:reason]).to eq("Validation failed")
      end
    end

    context "with skipping task" do
      let(:workflow_class) do
        before_task = create_simple_task(name: "BeforeTask")
        skipping_task = create_skipping_task(name: "SkippingTask", reason: "Feature disabled")
        after_task = create_simple_task(name: "AfterTask")

        create_workflow_class do
          process before_task
          process skipping_task
          process after_task
        end
      end

      it "continues execution after skipped task" do
        result = workflow_class.call(context_data)

        expect(result).to be_success
        expect(result.context.executed).to be(true)
      end
    end

    context "with erroring task" do
      let(:workflow_class) do
        before_task = create_simple_task(name: "BeforeTask")
        erroring_task = create_erroring_task(name: "ErroringTask", reason: "System error")
        after_task = create_simple_task(name: "AfterTask")

        create_workflow_class do
          process before_task
          process erroring_task
          process after_task
        end
      end

      it "converts error to failed result and halts" do
        result = workflow_class.call(context_data)

        expect(result).to be_failed
        expect(result.metadata[:reason]).to include("System error")
      end
    end

    context "with conditional execution" do
      context "when if condition is true" do
        let(:workflow_class) do
          conditional_task = create_simple_task(name: "ConditionalTask")
          always_task = create_simple_task(name: "AlwaysTask")

          create_workflow_class do
            process conditional_task, if: -> { context.user_id > 100 }
            process always_task
          end
        end

        it "executes conditional group" do
          result = workflow_class.call(context_data)

          expect(result).to be_success
          expect(result.context.executed).to be(true)
        end
      end

      context "when if condition is false" do
        let(:workflow_class) do
          conditional_task = create_simple_task(name: "ConditionalTask")
          always_task = create_simple_task(name: "AlwaysTask")

          create_workflow_class do
            process conditional_task, if: -> { context.user_id < 100 }
            process always_task
          end
        end

        it "skips conditional group" do
          result = workflow_class.call(context_data)

          expect(result).to be_success
        end
      end

      context "when unless condition is true" do
        let(:workflow_class) do
          conditional_task = create_simple_task(name: "ConditionalTask")
          always_task = create_simple_task(name: "AlwaysTask")

          create_workflow_class do
            process conditional_task, unless: -> { context.user_id > 100 }
            process always_task
          end
        end

        it "skips conditional group" do
          result = workflow_class.call(context_data)

          expect(result).to be_success
        end
      end

      context "when unless condition is false" do
        let(:workflow_class) do
          conditional_task = create_simple_task(name: "ConditionalTask")
          always_task = create_simple_task(name: "AlwaysTask")

          create_workflow_class do
            process conditional_task, unless: -> { context.user_id < 100 }
            process always_task
          end
        end

        it "executes conditional group" do
          result = workflow_class.call(context_data)

          expect(result).to be_success
          expect(result.context.executed).to be(true)
        end
      end
    end

    context "with workflow halt configuration" do
      context "when workflow_halt is set to failed" do
        let(:workflow_class) do
          before_task = create_simple_task(name: "BeforeTask")
          failing_task = create_failing_task(name: "FailingTask")
          after_task = create_simple_task(name: "AfterTask")

          create_workflow_class do
            process before_task
            process failing_task, workflow_halt: :failed
            process after_task
          end
        end

        it "halts on failed status" do
          result = workflow_class.call(context_data)

          expect(result).to be_failed
        end
      end

      context "when workflow_halt is set to skipped" do
        let(:workflow_class) do
          before_task = create_simple_task(name: "BeforeTask")
          skipping_task = create_skipping_task(name: "SkippingTask")
          after_task = create_simple_task(name: "AfterTask")

          create_workflow_class do
            process before_task
            process skipping_task, workflow_halt: :skipped
            process after_task
          end
        end

        it "halts on skipped status" do
          result = workflow_class.call(context_data)

          expect(result).to be_skipped
        end
      end

      context "when workflow_halt is set to array of statuses" do
        let(:workflow_class) do
          before_task = create_simple_task(name: "BeforeTask")
          skipping_task = create_skipping_task(name: "SkippingTask")
          after_task = create_simple_task(name: "AfterTask")

          create_workflow_class do
            process before_task
            process skipping_task, workflow_halt: %i[failed skipped]
            process after_task
          end
        end

        it "halts on any specified status" do
          result = workflow_class.call(context_data)

          expect(result).to be_skipped
        end
      end

      context "when workflow_halt is empty array" do
        let(:workflow_class) do
          before_task = create_simple_task(name: "BeforeTask")
          failing_task = create_failing_task(name: "FailingTask")
          after_task = create_simple_task(name: "AfterTask")

          create_workflow_class do
            process before_task
            process failing_task, workflow_halt: []
            process after_task
          end
        end

        it "continues execution regardless of status" do
          result = workflow_class.call(context_data)

          expect(result).to be_success
          expect(result.context.executed).to be(true)
        end
      end

      context "when workflow_halt is set via cmd_setting" do
        let(:workflow_class) do
          before_task = create_simple_task(name: "BeforeTask")
          skipping_task = create_skipping_task(name: "SkippingTask")
          after_task = create_simple_task(name: "AfterTask")

          create_workflow_class do
            cmd_settings!(workflow_halt: :skipped)
            process before_task
            process skipping_task
            process after_task
          end
        end

        it "uses cmd_setting for halt behavior" do
          result = workflow_class.call(context_data)

          expect(result).to be_skipped
        end
      end

      context "when group workflow_halt overrides cmd_setting" do
        let(:workflow_class) do
          before_task = create_simple_task(name: "BeforeTask")
          skipping_task = create_skipping_task(name: "SkippingTask")
          after_task = create_simple_task(name: "AfterTask")

          create_workflow_class do
            cmd_settings!(workflow_halt: :skipped)
            process before_task
            process skipping_task, workflow_halt: []
            process after_task
          end
        end

        it "uses group-level workflow_halt setting" do
          result = workflow_class.call(context_data)

          expect(result).to be_success
          expect(result.context.executed).to be(true)
        end
      end
    end

    context "with nested workflows" do
      let(:inner_workflow_class) do
        inner_task = create_simple_task(name: "InnerTask")

        create_workflow_class(name: "InnerWorkflow") do
          process inner_task
        end
      end

      let(:workflow_class) do
        inner = inner_workflow_class
        before_task = create_simple_task(name: "BeforeTask")
        after_task = create_simple_task(name: "AfterTask")

        create_workflow_class(name: "OuterWorkflow") do
          process before_task
          process inner
          process after_task
        end
      end

      it "executes nested workflows" do
        result = workflow_class.call(context_data)

        expect(result).to be_success
        expect(result.context.executed).to be(true)
      end
    end

    context "with complex workflow scenario" do
      let(:workflow_class) do
        validate_task = create_simple_task(name: "ValidateInput")
        premium_task = create_failing_task(name: "ProcessPremium", reason: "Unauthorized")
        payment_task = create_failing_task(name: "ProcessPayment", reason: "Payment failed")
        confirmation_task = create_simple_task(name: "SendConfirmation")

        create_workflow_class(name: "ComplexWorkflow") do
          # Initial validation
          process validate_task

          # # Conditional processing - user_id 123 is not > 1000, so this should be skipped
          process premium_task, if: ->(workflow) { workflow.context.user_id > 1000 }

          # Main processing that might fail
          process payment_task, workflow_halt: :failed

          # This should not execute due to halt
          process confirmation_task

          private

          def id_limit?
            context.user_id > 1000
          end
        end
      end

      it "executes conditional logic and halts appropriately" do
        result = workflow_class.call(context_data)

        expect(result).to be_failed
        expect(result.metadata[:reason]).to eq("Payment failed")
      end
    end

    context "without workflow groups" do
      let(:workflow_class) { create_workflow_class }

      it "completes successfully with no tasks" do
        result = workflow_class.call(context_data)

        expect(result).to be_success
      end
    end

    context "with context propagation" do
      let(:workflow_class) do
        step1_task = create_task_class do
          define_method :call do
            context.step1_completed = true
            context.processed_data = "step1"
          end
        end

        step2_task = create_task_class do
          define_method :call do
            context.step2_completed = true
            context.processed_data += "_step2"
          end
        end

        create_workflow_class do
          process step1_task
          process step2_task
        end
      end

      it "maintains context across all tasks" do
        result = workflow_class.call(context_data)

        expect(result.context.step1_completed).to be(true)
        expect(result.context.step2_completed).to be(true)
        expect(result.context.processed_data).to eq("step1_step2")
        expect(result.context.user_id).to eq(123)
      end
    end
  end

  context "when using workflow builders" do
    describe "simple workflow" do
      let(:tasks) do
        [
          create_simple_task(name: "Task1"),
          create_simple_task(name: "Task2"),
          create_simple_task(name: "Task3")
        ]
      end
      let(:workflow_class) { create_simple_workflow(tasks: tasks, name: "BuilderWorkflow") }

      it "executes all tasks in sequence" do
        result = workflow_class.call(context_data)

        expect(result).to be_success
        expect(result.context.executed).to be(true)
      end
    end

    describe "successful workflow" do
      let(:workflow_class) do
        success_task_one = create_simple_task(name: "SuccessfulTask1")
        success_task_two = create_simple_task(name: "SuccessfulTask2")
        success_task3 = create_simple_task(name: "SuccessfulTask3")

        create_workflow_class(name: "SuccessWorkflow") do
          process success_task_one
          process success_task_two
          process success_task3
        end
      end

      it "completes successfully" do
        result = workflow_class.call(context_data)

        expect(result).to be_success
      end
    end

    describe "failing workflow" do
      let(:workflow_class) do
        pre_task = create_simple_task(name: "PreFailTask")
        fail_task = create_failing_task(name: "FailingTask")
        post_task = create_simple_task(name: "PostFailTask")

        create_workflow_class(name: "FailWorkflow") do
          process pre_task
          process fail_task
          process post_task
        end
      end

      it "fails appropriately" do
        result = workflow_class.call(context_data)

        expect(result).to be_failed
      end
    end

    describe "skipping workflow" do
      let(:workflow_class) do
        pre_task = create_simple_task(name: "PreSkipTask")
        skip_task = create_skipping_task(name: "SkippingTask")
        post_task = create_simple_task(name: "PostSkipTask")

        create_workflow_class(name: "SkipWorkflow") do
          process pre_task
          process skip_task
          process post_task
        end
      end

      it "handles skipped tasks" do
        result = workflow_class.call(context_data)

        expect(result).to be_success
      end
    end

    describe "erroring workflow" do
      let(:workflow_class) do
        pre_task = create_simple_task(name: "PreErrorTask")
        error_task = create_erroring_task(name: "ErroringTask")
        post_task = create_simple_task(name: "PostErrorTask")

        create_workflow_class(name: "ErrorWorkflow") do
          process pre_task
          process error_task
          process post_task
        end
      end

      it "handles erroring tasks" do
        result = workflow_class.call(context_data)

        expect(result).to be_failed
      end
    end
  end
end
