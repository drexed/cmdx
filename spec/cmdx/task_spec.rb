# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Task do
  subject(:result) { SimulationTask.call(simulate:) }

  let(:simulate) { :success }

  describe "#hooks" do
    subject(:result) { hooks_task.call(simulate:) }

    let(:parent_task) do
      Class.new(SimulationTask) do
        before_execution :before_execution_hook
        after_execution :after_execution_hook

        on_executing :on_executing_hook
        on_complete :on_complete_hook
        on_interrupted :on_interrupted_hook
        on_executed :on_executed_hook

        before_validation :before_validation_hook
        after_validation :after_validation_hook

        on_success :on_success_hook
        on_skipped :on_skipped_hook
        on_failed :on_failed_hook
        on_good :on_good_hook
        on_bad :on_bad_hook

        on_complete :with_conditional_method_hook, if: :truthy?
        on_complete :with_conditional_proc_hook, unless: proc { true }

        def self.name
          "ParentTask"
        end

        private

        def truthy?
          true
        end

        def trace_hook(method)
          (ctx.hooks ||= []) << "#{self.class.name || 'Unknown'}.#{method}"
        end

        (CMDx::Task::HOOKS + %i[with_conditional_method with_conditional_proc]).each do |h|
          define_method(:"#{h}_hook") { trace_hook(__method__) }
        end
      end
    end

    let(:hooks_task) do
      Class.new(parent_task) do
        on_success :other_success_hook
        on_success proc { trace_hook(:proc_success_hook) }

        def self.name
          "ChildTask"
        end

        private

        def other_success_hook
          trace_hook(__method__)
        end
      end
    end

    context "when task succeeds" do
      let(:simulate) { :success }

      it_behaves_like "task hooks execution", %w[
        ChildTask.before_execution_hook
        ChildTask.on_executing_hook
        ChildTask.before_validation_hook
        ChildTask.after_validation_hook
        ChildTask.on_complete_hook
        ChildTask.with_conditional_method_hook
        ChildTask.on_executed_hook
        ChildTask.on_success_hook
        ChildTask.other_success_hook
        ChildTask.proc_success_hook
        ChildTask.on_good_hook
        ChildTask.after_execution_hook
      ]
    end

    context "when task is skipped" do
      let(:simulate) { :skipped }

      it_behaves_like "task hooks execution", %w[
        ChildTask.before_execution_hook
        ChildTask.on_executing_hook
        ChildTask.before_validation_hook
        ChildTask.after_validation_hook
        ChildTask.on_interrupted_hook
        ChildTask.on_executed_hook
        ChildTask.on_skipped_hook
        ChildTask.on_good_hook
        ChildTask.on_bad_hook
        ChildTask.after_execution_hook
      ]
    end

    context "when task fails" do
      let(:simulate) { :failed }

      it_behaves_like "task hooks execution", %w[
        ChildTask.before_execution_hook
        ChildTask.on_executing_hook
        ChildTask.before_validation_hook
        ChildTask.after_validation_hook
        ChildTask.on_interrupted_hook
        ChildTask.on_executed_hook
        ChildTask.on_failed_hook
        ChildTask.on_bad_hook
        ChildTask.after_execution_hook
      ]
    end
  end

  describe ".call" do
    context "when call not implemented" do
      let(:simulation_task) do
        Class.new(ApplicationTask) do
          def self.name
            "AnonymousTask"
          end
        end
      end

      it "raises CMDx::UndefinedCallError" do
        expect { simulation_task.call }.to raise_error(CMDx::UndefinedCallError, "call method not defined in AnonymousTask")
      end
    end

    context "when task succeeds" do
      it_behaves_like "a successful result"
    end

    context "when task is skipped" do
      let(:simulate) { :skipped }

      it_behaves_like "a skipped result"
    end

    context "when task fails" do
      let(:simulate) { :failed }

      it_behaves_like "a failed result"
    end

    context "when bang child failed" do
      let(:simulate) { :child_failed! }

      it "returns correct result" do
        expect(result).to be_failed
        expect(result).not_to be_good
        expect(result).to be_bad
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: { original_exception: an_instance_of(CMDx::Failed) }
        )
      end
    end

    context "when non-bang child failed" do
      let(:simulate) { :child_failed }

      it "returns correct result" do
        expect(result).to be_failed
        expect(result).not_to be_good
        expect(result).to be_bad
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {}
        )
      end
    end

    context "when exception" do
      let(:simulate) { :exception }

      it "returns correct result" do
        expect(result).to be_failed
        expect(result).not_to be_good
        expect(result).to be_bad
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::FAILED,
          metadata: {
            reason: "[RuntimeError] undefined simulation type: :exception",
            original_exception: an_instance_of(RuntimeError)
          }
        )
      end
    end
  end

  describe ".call!" do
    context "when success" do
      it "does not raise an error" do
        expect { SimulationTask.call!(simulate:) }.not_to raise_error
      end
    end

    context "when skipped" do
      let(:simulate) { :skipped }

      context "without skipped task_halt option" do
        it "does not raise an error" do
          expect { SimulationTask.call!(simulate:) }.not_to raise_error
        end
      end

      context "with skipped task_halt option" do
        let(:simulation_task) do
          Class.new(SimulationTask) do
            task_settings!(task_halt: [CMDx::Result::SKIPPED])
          end
        end

        it "raises Skipped fault" do
          expect { simulation_task.call!(simulate:) }.to raise_error(CMDx::Skipped)
        end
      end
    end

    context "when failed" do
      let(:simulate) { :failed }

      it "raise Failed fault" do
        expect { SimulationTask.call!(simulate:) }.to raise_error(CMDx::Failed)
      end
    end

    context "when exception" do
      let(:simulate) { :exception }

      it "raise RuntimeError" do
        expect { SimulationTask.call!(simulate:) }.to raise_error(RuntimeError, "undefined simulation type: :exception")
      end
    end
  end

  describe "direct instantiation" do
    let(:task) { SimulationTask.new(simulate: :success) }

    describe "#new" do
      it "creates a task instance with proper initialization" do
        expect(task).to be_a(SimulationTask)
        expect(task.id).to be_a(String)
        expect(task.id.length).to eq(36) # UUID length
        expect(task.context.simulate).to eq(:success)
        expect(task.result.state).to eq(CMDx::Result::INITIALIZED)
        expect(task.result.status).to eq(CMDx::Result::SUCCESS)
      end

      it "creates unique instances" do
        # Allow real UUID generation for this test
        allow(SecureRandom).to receive(:uuid).and_call_original

        task1 = SimulationTask.new(simulate: :success)
        task2 = SimulationTask.new(simulate: :success)

        expect(task1.id).not_to eq(task2.id)
        expect(task1).not_to equal(task2)
        expect(task1.object_id).not_to eq(task2.object_id)
      end

      it "accepts context parameters" do
        task_with_params = SimulationTask.new(
          simulate: :success,
          custom_param: "test_value",
          numeric_param: 123
        )

        expect(task_with_params.context.simulate).to eq(:success)
        expect(task_with_params.context.custom_param).to eq("test_value")
        expect(task_with_params.context.numeric_param).to eq(123)
      end
    end

    describe "#perform" do
      context "when task succeeds" do
        let(:task) { SimulationTask.new(simulate: :success) }

        it "executes the task and returns success result" do
          expect(task.result.state).to eq(CMDx::Result::INITIALIZED)

          task.perform

          expect(task.result).to be_success
          expect(task.result).to be_complete
          expect(task.result).to be_good
          expect(task.result.state).to eq(CMDx::Result::COMPLETE)
          expect(task.result.status).to eq(CMDx::Result::SUCCESS)
        end

        it "finalizes the task after execution" do
          expect(task).not_to be_frozen
          expect(task.result.state).to eq(CMDx::Result::INITIALIZED)

          task.perform

          # In test environment, freezing is disabled, but we can check other aspects
          expect(task.result.state).to eq(CMDx::Result::COMPLETE)
          expect(task.result.status).to eq(CMDx::Result::SUCCESS)
        end

        it "records execution runtime" do
          task.perform

          expect(task.result.runtime).to be_a(Numeric)
          expect(task.result.runtime).to be >= 0
        end
      end

      context "when task is skipped" do
        let(:task) { SimulationTask.new(simulate: :skipped) }

        it "executes the task and returns skipped result" do
          task.perform

          expect(task.result).to be_skipped
          expect(task.result).to be_interrupted
          expect(task.result).to be_good
          expect(task.result).to be_bad
          expect(task.result.state).to eq(CMDx::Result::INTERRUPTED)
          expect(task.result.status).to eq(CMDx::Result::SKIPPED)
        end
      end

      context "when task fails" do
        let(:task) { SimulationTask.new(simulate: :failed) }

        it "executes the task and returns failed result" do
          task.perform

          expect(task.result).to be_failed
          expect(task.result).to be_interrupted
          expect(task.result).to be_bad
          expect(task.result.state).to eq(CMDx::Result::INTERRUPTED)
          expect(task.result.status).to eq(CMDx::Result::FAILED)
        end
      end

      context "when task raises exception" do
        let(:task) { SimulationTask.new(simulate: :exception) }

        it "handles exceptions and returns failed result" do
          task.perform

          expect(task.result).to be_failed
          expect(task.result).to be_interrupted
          expect(task.result).to be_bad
          expect(task.result.metadata[:reason]).to include("RuntimeError")
          expect(task.result.metadata[:original_exception]).to be_a(RuntimeError)
        end
      end

      it "cannot be executed multiple times" do
        task.perform
        expect(task.result.state).to eq(CMDx::Result::COMPLETE)

        # Attempting to execute again should fail due to state transition rules
        expect { task.perform }.to raise_error(RuntimeError, /cannot transition to interrupted from complete/)
      end
    end

    describe "task state access" do
      let(:task) { SimulationTask.new(simulate: :success, test_param: "value") }

      it "provides access to task properties before execution" do
        # Before execution
        expect(task.context.test_param).to eq("value")
        expect(task.result.state).to eq(CMDx::Result::INITIALIZED)
        expect(task.errors).to be_empty

        # Execute
        task.perform

        # After execution
        expect(task.result.state).to eq(CMDx::Result::COMPLETE)
        expect(task.result.status).to eq(CMDx::Result::SUCCESS)
      end

      it "allows inspection of task configuration" do
        expect(task.class.cmd_parameters).to be_a(CMDx::Parameters)
        expect(task.class.cmd_middlewares).to be_a(CMDx::MiddlewareRegistry)
        expect(task.class.cmd_hooks).to be_a(Hash)
      end
    end
  end
end
