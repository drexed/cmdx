# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Workflow, type: :unit do
  let(:workflow_class) { create_workflow_class(name: "TestWorkflow") }
  let(:workflow) { workflow_class.new }
  let(:context_hash) { { executed: [] } }
  let(:workflow_with_context) { workflow_class.new(context_hash) }

  describe "module inclusion" do
    it "extends the class with ClassMethods" do
      expect(workflow_class).to respond_to(:execution_groups)
      expect(workflow_class).to respond_to(:task)
      expect(workflow_class).to respond_to(:tasks)
    end

    it "includes workflow functionality in the instance" do
      expect(workflow).to respond_to(:work)
    end
  end

  describe "ExecutionGroup" do
    subject(:execution_group) { CMDx::Workflow::ExecutionGroup.new(tasks, options) }

    let(:tasks) { [create_successful_task] }
    let(:options) { { if: true } }

    it "is a Struct with tasks and options" do
      expect(execution_group.tasks).to eq(tasks)
      expect(execution_group.options).to eq(options)
    end
  end

  describe "ClassMethods" do
    describe "#method_added" do
      context "when redefining work method" do
        it "raises an error" do
          expect do
            workflow_class.class_eval do
              def work
                "custom work"
              end
            end
          end.to raise_error(RuntimeError, /cannot redefine.*#work method/)
        end
      end

      context "when adding other methods" do
        it "allows normal method definition" do
          expect do
            workflow_class.class_eval do
              def custom_method
                "allowed"
              end
            end
          end.not_to raise_error

          expect(workflow_class.new).to respond_to(:custom_method)
        end
      end
    end

    describe "#execution_groups" do
      it "initializes as empty array" do
        expect(workflow_class.execution_groups).to eq([])
      end

      it "memoizes the execution_groups" do
        groups = workflow_class.execution_groups

        expect(workflow_class.execution_groups).to be(groups)
      end
    end

    describe "#tasks" do
      let(:task1) { create_successful_task(name: "Task1") }
      let(:task2) { create_successful_task(name: "Task2") }
      let(:options) { { if: true, breakpoints: [:failure] } }

      context "with valid CMDx::Task classes" do
        it "adds execution group to execution_groups" do
          workflow_class.tasks(task1, task2, **options)

          expect(workflow_class.execution_groups.size).to eq(1)

          group = workflow_class.execution_groups.first

          expect(group.tasks).to eq([task1, task2])
          expect(group.options).to eq(options)
        end

        it "supports multiple task declarations" do
          workflow_class.tasks(task1, **options)
          workflow_class.tasks(task2, if: false)

          expect(workflow_class.execution_groups.size).to eq(2)
          expect(workflow_class.execution_groups[0].tasks).to eq([task1])
          expect(workflow_class.execution_groups[1].tasks).to eq([task2])
        end
      end

      context "with invalid task types" do
        it "raises TypeError for non-Task classes" do
          expect do
            workflow_class.tasks(String, Integer)
          end.to raise_error(TypeError, "must be a CMDx::Task")
        end

        it "raises TypeError for regular objects" do
          expect do
            workflow_class.tasks("not a task")
          end.to raise_error(TypeError, "must be a CMDx::Task")
        end
      end

      context "with mixed valid and invalid tasks" do
        it "raises TypeError when any task is invalid" do
          expect do
            workflow_class.tasks(task1, String, task2)
          end.to raise_error(TypeError, "must be a CMDx::Task")
        end
      end
    end
  end

  describe "#work" do
    let(:task1) { create_successful_task(name: "Task1") }
    let(:task2) { create_successful_task(name: "Task2") }
    let(:task3) { create_successful_task(name: "Task3") }

    before do
      workflow_class.class_eval do
        settings workflow_breakpoints: []
      end
    end

    context "with single execution group" do
      before do
        workflow_class.tasks(task1, task2, task3)
      end

      it "executes all tasks in sequence" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success success])
      end
    end

    context "with multiple execution groups" do
      before do
        workflow_class.tasks(task1)
        workflow_class.tasks(task2, task3)
      end

      it "executes all groups in sequence" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success success])
      end
    end

    context "with conditional execution" do
      before do
        workflow_class.tasks(task1, if: true)
        workflow_class.tasks(task2, if: false)
        workflow_class.tasks(task3, unless: false)
      end

      it "only executes tasks when conditions are met" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success])
      end
    end

    context "with breakpoints in group options" do
      let(:failing_task) { create_failing_task(name: "FailingTask") }

      before do
        workflow_class.tasks(task1, failing_task, task3, breakpoints: [:failed])
      end

      it "stops execution when task status matches breakpoint" do
        expect { workflow_with_context.work }.to raise_error(CMDx::FailFault)

        expect(workflow_with_context.context.executed).to eq([:success])
      end
    end

    context "with breakpoints in class settings" do
      before do
        workflow_class.class_eval do
          settings workflow_breakpoints: [:skipped]
        end

        workflow_class.tasks(task1, task2, task3)
      end

      it "executes all tasks when no task matches breakpoints" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success success])
      end
    end

    context "with group breakpoints overriding class breakpoints" do
      before do
        workflow_class.class_eval do
          settings workflow_breakpoints: [:skipped]
        end

        workflow_class.tasks(task1, task2, task3, breakpoints: [:failed])
      end

      it "uses group breakpoints instead of class breakpoints" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success success])
      end
    end

    context "when breakpoints is nil" do
      before do
        workflow_class.class_eval do
          settings workflow_breakpoints: [:failed]
        end

        workflow_class.tasks(task1, task2, task3, breakpoints: nil)
      end

      it "uses class-level breakpoints" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success success])
      end
    end

    context "with different breakpoint types" do
      let(:failing_task) { create_nested_task(strategy: :throw, status: :failure) }

      context "when breakpoints is a single symbol" do
        before do
          workflow_class.tasks(task1, failing_task, task3, breakpoints: :failed)
        end

        it "converts single breakpoint to array" do
          expect(workflow_with_context).to receive(:throw!)

          workflow_with_context.work
        end
      end

      context "when breakpoints is a string" do
        before do
          workflow_class.tasks(task1, failing_task, task3, breakpoints: "failed")
        end

        it "converts string breakpoint to array and compares as string" do
          expect(workflow_with_context).to receive(:throw!)

          workflow_with_context.work
        end
      end

      context "when breakpoints contains duplicates" do
        before do
          workflow_class.tasks(task1, failing_task, task3, breakpoints: [:failed, :failed, "failed"])
        end

        it "removes duplicates and converts to strings" do
          expect(workflow_with_context).to receive(:throw!)

          workflow_with_context.work
        end
      end
    end

    context "when task status does not match breakpoints" do
      let(:failing_task) { create_nested_task(strategy: :throw, status: :failure) }

      before do
        workflow_class.tasks(task1, failing_task, task3, breakpoints: [:skipped])
      end

      it "continues execution" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success])
      end
    end

    context "when execution group condition evaluates to false" do
      before do
        workflow_class.tasks(task1, if: false)
        workflow_class.tasks(task2, unless: true)
        workflow_class.tasks(task3)
      end

      it "skips groups that do not meet conditions" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq([:success])
      end
    end

    context "with complex conditional scenarios" do
      before do
        workflow_class.tasks(task1, if: true)
        workflow_class.tasks(task2, if: false)
        workflow_class.tasks(task3, unless: false)
      end

      it "evaluates conditions against workflow instance" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq(%i[success success])
      end
    end

    context "with empty execution groups" do
      it "completes without executing any tasks" do
        workflow_with_context.work

        expect(workflow_with_context.context.executed).to eq([])
      end
    end
  end
end
