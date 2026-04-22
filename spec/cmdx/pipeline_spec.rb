# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Pipeline do
  after { CMDx::Chain.clear }

  describe ".execute" do
    it "delegates to a new Pipeline instance" do
      workflow_instance = create_workflow_class.new
      pipeline = instance_double(described_class)
      expect(described_class).to receive(:new).with(workflow_instance).and_return(pipeline)
      expect(pipeline).to receive(:execute)

      described_class.execute(workflow_instance)
    end
  end

  describe "#execute" do
    context "with an empty pipeline" do
      it "is a no-op" do
        workflow_class = create_workflow_class
        result = workflow_class.execute

        expect(result).to be_success
        expect(result.chain.size).to eq(1)
      end
    end

    context "when a group has no tasks" do
      it "is a silent no-op (declaration-time validation prevents this in normal use)" do
        workflow_class = create_workflow_class
        workflow_class.pipeline << CMDx::Workflow::ExecutionGroup.new(tasks: [], options: {})

        expect(workflow_class.execute).to be_success
      end
    end

    context "with an invalid strategy" do
      it "propagates ArgumentError via execute!" do
        task = create_successful_task
        workflow_class = create_workflow_class do
          tasks task, strategy: :bogus
        end

        expect { workflow_class.execute! }.to raise_error(ArgumentError, /invalid strategy: :bogus/)
      end
    end

    context "with :if guard" do
      it "skips the group when the guard is false" do
        task = create_failing_task(reason: "should not run")
        workflow_class = create_workflow_class do
          tasks task, if: proc { false }
        end

        expect(workflow_class.execute).to be_success
      end

      it "runs the group when the guard is true" do
        task = create_successful_task
        workflow_class = create_workflow_class do
          tasks task, if: proc { true }
        end

        expect(workflow_class.execute).to be_success
      end
    end

    context "with :unless guard" do
      it "skips the group when the guard is true" do
        task = create_failing_task(reason: "should not run")
        workflow_class = create_workflow_class do
          tasks task, unless: proc { true }
        end

        expect(workflow_class.execute).to be_success
      end
    end

    describe "sequential strategy" do
      it "runs each task in order" do
        task1 = create_successful_task(name: "T1")
        task2 = create_successful_task(name: "T2")
        workflow_class = create_workflow_class do
          tasks task1, task2
        end

        result = workflow_class.execute
        expect(result.chain.map { |r| r.task.name }).to match([/AnonymousWorkflow/, /T1/, /T2/])
      end

      it "halts the group when a task fails" do
        task1 = create_failing_task(reason: "stop")
        task2 = create_successful_task(name: "NeverRun")
        workflow_class = create_workflow_class do
          tasks task1, task2
        end

        result = workflow_class.execute
        expect(result).to be_failed
        task_names = result.chain.map { |r| r.task.name }
        expect(task_names.any? { |n| n.include?("NeverRun") }).to be(false)
      end
    end

    describe "parallel strategy" do
      it "runs every task regardless of failure" do
        task1 = create_failing_task(name: "Failing1", reason: "f1")
        task2 = create_successful_task(name: "Succ2")
        task3 = create_successful_task(name: "Succ3")

        workflow_class = create_workflow_class do
          tasks task1, task2, task3, strategy: :parallel
        end

        result = workflow_class.execute

        expect(result).to be_failed
        task_names = result.chain.map { |r| r.task.name }
        expect(task_names.count { |n| n.include?("Succ2") }).to eq(1)
        expect(task_names.count { |n| n.include?("Succ3") }).to eq(1)
      end

      it "respects :pool_size" do
        task1 = create_successful_task(name: "Par1")
        task2 = create_successful_task(name: "Par2")

        workflow_class = create_workflow_class do
          tasks task1, task2, strategy: :parallel, pool_size: 1
        end

        expect(workflow_class.execute).to be_success
      end

      describe ":fail_fast" do
        it "skips queued tasks after the first failure (pool_size: 1)" do
          failing = create_failing_task(name: "First", reason: "stop")
          never_run = create_task_class(name: "NeverRun") do
            define_method(:work) { context.ran = true }
          end

          workflow_class = create_workflow_class do
            tasks failing, never_run, strategy: :parallel, pool_size: 1, fail_fast: true
          end

          result = workflow_class.execute
          expect(result).to be_failed
          expect(result.reason).to eq("stop")
          expect(result.context[:ran]).to be_nil
          task_names = result.chain.map { |r| r.task.name }
          expect(task_names.any? { |n| n.include?("NeverRun") }).to be(false)
        end

        it "runs every task when fail_fast is false (default behavior preserved)" do
          failing = create_failing_task(name: "First", reason: "stop")
          other = create_task_class(name: "Other") do
            define_method(:work) { context.ran = true }
          end

          workflow_class = create_workflow_class do
            tasks failing, other, strategy: :parallel, pool_size: 1
          end

          result = workflow_class.execute
          expect(result).to be_failed
          expect(result.context[:ran]).to be(true)
        end

        it "merges context from tasks that completed before the failure was observed" do
          ok = create_task_class(name: "Ok") do
            define_method(:work) { context.ok = true }
          end
          failing = create_failing_task(name: "Fail", reason: "boom")
          never_run = create_task_class(name: "NeverRun") do
            define_method(:work) { context.ran = true }
          end

          workflow_class = create_workflow_class do
            tasks ok, failing, never_run, strategy: :parallel, pool_size: 1, fail_fast: true
          end

          result = workflow_class.execute
          expect(result).to be_failed
          expect(result.context[:ok]).to be(true)
          expect(result.context[:ran]).to be_nil
        end
      end
    end
  end
end
