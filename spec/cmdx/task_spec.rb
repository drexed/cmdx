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

    context "when success" do
      let(:simulate) { :success }

      it "calls hooks in correct order" do
        expect(result.context.hooks).to eq(
          %w[
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
        )
      end
    end

    context "when skipped" do
      let(:simulate) { :skipped }

      it "calls hooks in correct order" do
        expect(result.context.hooks).to eq(
          %w[
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
        )
      end
    end

    context "when failed" do
      let(:simulate) { :failed }

      it "calls hooks in correct order" do
        expect(result.context.hooks).to eq(
          %w[
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
        )
      end
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

    context "when success" do
      it "returns correct result" do
        expect(result).to be_success
        expect(result).to be_good
        expect(result).not_to be_bad
        expect(result).to have_attributes(
          state: CMDx::Result::COMPLETE,
          status: CMDx::Result::SUCCESS,
          metadata: {}
        )
      end
    end

    context "when skipped" do
      let(:simulate) { :skipped }

      it "returns correct result" do
        expect(result).to be_skipped
        expect(result).to be_good
        expect(result).to be_bad
        expect(result).to have_attributes(
          state: CMDx::Result::INTERRUPTED,
          status: CMDx::Result::SKIPPED,
          metadata: {}
        )
      end
    end

    context "when failed" do
      let(:simulate) { :failed }

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
end
