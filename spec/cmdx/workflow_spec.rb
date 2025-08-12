# frozen_string_literal: true

require "spec_helper"

RSpec.describe CMDx::Workflow do
  let(:workflow_class) { create_workflow_class(name: "TestWorkflow") }
  let(:task_class) { create_successful_task(name: "TestTask") }
  let(:invalid_task) { String }

  describe "#method_added" do
    context "when trying to redefine work method" do
      it "raises an error" do
        expect do
          workflow_class.class_eval do
            def work
              "redefined work"
            end
          end
        end.to raise_error(RuntimeError, /cannot redefine.*#work method/)
      end
    end

    context "when defining other methods" do
      it "allows method definition" do
        expect do
          workflow_class.class_eval do
            def custom_method
              "custom"
            end
          end
        end.not_to raise_error
      end
    end
  end

  describe "#work" do
    let(:workflow_instance) { workflow_class.new }
    let(:task_result) { instance_double(CMDx::Result, status: "success") }
    let(:context) { instance_double(CMDx::Context) }

    before do
      allow(workflow_instance).to receive(:context).and_return(context)
    end

    context "with no execution groups" do
      it "completes without executing anything" do
        expect { workflow_instance.work }.not_to raise_error
      end
    end

    context "with single execution group" do
      before do
        workflow_class.tasks(task_class)
        allow(task_class).to receive(:execute).and_return(task_result)
      end

      context "when condition evaluates to true" do
        before do
          allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)
        end

        it "executes tasks in the group" do
          workflow_instance.work
          expect(task_class).to have_received(:execute).with(context)
        end

        context "without breakpoints" do
          before do
            allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: nil })
          end

          it "continues execution regardless of task status" do
            expect { workflow_instance.work }.not_to raise_error
          end
        end

        context "with default breakpoints from settings" do
          before do
            allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: %w[failure error] })
          end

          context "when task status matches breakpoint" do
            let(:task_result) { instance_double(CMDx::Result, status: "failure") }

            it "calls throw! with the result" do
              throw_spy = instance_spy("ThrowHandler")
              allow(workflow_instance).to receive(:throw!) { |result| throw_spy.call(result) }

              workflow_instance.work

              expect(throw_spy).to have_received(:call).with(task_result)
            end
          end

          context "when task status does not match breakpoint" do
            let(:task_result) { instance_double(CMDx::Result, status: "success") }

            it "continues without calling throw!" do
              throw_spy = instance_spy("ThrowHandler")
              allow(workflow_instance).to receive(:throw!) { |result| throw_spy.call(result) }

              workflow_instance.work

              expect(throw_spy).not_to have_received(:call)
            end
          end
        end

        context "with group-specific breakpoints" do
          before do
            workflow_class.execution_groups.clear
            workflow_class.tasks(task_class, breakpoints: ["custom_status"])
            allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: ["failure"] })
          end

          context "when task status matches group breakpoint" do
            let(:task_result) { instance_double(CMDx::Result, status: "custom_status") }

            it "calls throw! with the result" do
              throw_spy = instance_spy("ThrowHandler")
              allow(workflow_instance).to receive(:throw!) { |result| throw_spy.call(result) }

              workflow_instance.work

              expect(throw_spy).to have_received(:call).with(task_result)
            end
          end

          context "when task status matches default but not group breakpoint" do
            let(:task_result) { instance_double(CMDx::Result, status: "failure") }

            it "continues without calling throw!" do
              throw_spy = instance_spy("ThrowHandler")
              allow(workflow_instance).to receive(:throw!) { |result| throw_spy.call(result) }

              workflow_instance.work

              expect(throw_spy).not_to have_received(:call)
            end
          end
        end

        context "with breakpoints as different types" do
          let(:throw_spy) { instance_spy("ThrowHandler") }

          before do
            workflow_class.execution_groups.clear
            allow(workflow_instance).to receive(:throw!) { |result| throw_spy.call(result) }
          end

          it "handles string breakpoints" do
            workflow_class.tasks(task_class, breakpoints: "failure")
            allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: nil })
            allow(task_result).to receive(:status).and_return("failure")

            workflow_instance.work

            expect(throw_spy).to have_received(:call).with(task_result)
          end

          it "handles symbol breakpoints" do
            workflow_class.tasks(task_class, breakpoints: :failure)
            allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: nil })
            allow(task_result).to receive(:status).and_return("failure")

            workflow_instance.work

            expect(throw_spy).to have_received(:call).with(task_result)
          end

          it "handles mixed array of symbols and strings" do
            workflow_class.tasks(task_class, breakpoints: [:failure, "error"])
            allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: nil })
            allow(task_result).to receive(:status).and_return("error")

            workflow_instance.work

            expect(throw_spy).to have_received(:call).with(task_result)
          end

          it "removes duplicates from breakpoints" do
            workflow_class.tasks(task_class, breakpoints: [:failure, "failure", :failure])
            allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: nil })
            allow(task_result).to receive(:status).and_return("failure")

            workflow_instance.work

            expect(throw_spy).to have_received(:call).with(task_result)
          end
        end
      end

      context "when condition evaluates to false" do
        before do
          allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(false)
        end

        it "skips execution of tasks in the group" do
          workflow_instance.work
          expect(task_class).not_to have_received(:execute)
        end
      end
    end

    context "with multiple execution groups" do
      let(:task2) { create_successful_task(name: "TestTask2") }
      let(:task_result2) { instance_double(CMDx::Result, status: "success") }

      before do
        workflow_class.tasks(task_class, if: true)
        workflow_class.tasks(task2, unless: false)
        allow(task_class).to receive(:execute).and_return(task_result)
        allow(task2).to receive(:execute).and_return(task_result2)
        allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: nil })
      end

      it "evaluates conditions for each group independently" do
        allow(CMDx::Utils::Condition).to receive(:evaluate).with(workflow_instance, { if: true }).and_return(true)
        allow(CMDx::Utils::Condition).to receive(:evaluate).with(workflow_instance, { unless: false }).and_return(false)

        workflow_instance.work

        expect(task_class).to have_received(:execute).with(context)
        expect(task2).not_to have_received(:execute)
      end

      it "executes all groups when conditions are met" do
        allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)

        workflow_instance.work

        expect(task_class).to have_received(:execute).with(context)
        expect(task2).to have_received(:execute).with(context)
      end
    end

    context "with multiple tasks in single group" do
      let(:task2) { create_successful_task(name: "TestTask2") }
      let(:task_result2) { instance_double(CMDx::Result, status: "failure") }

      before do
        workflow_class.tasks(task_class, task2, breakpoints: ["failure"])
        allow(task_class).to receive(:execute).and_return(task_result)
        allow(task2).to receive(:execute).and_return(task_result2)
        allow(CMDx::Utils::Condition).to receive(:evaluate).and_return(true)
        allow(workflow_class).to receive(:settings).and_return({ workflow_breakpoints: nil })
      end

      it "executes tasks in sequence" do
        throw_spy = instance_spy("ThrowHandler")
        allow(workflow_instance).to receive(:throw!) { |result| throw_spy.call(result) }

        workflow_instance.work

        expect(task_class).to have_received(:execute).with(context)
        expect(task2).to have_received(:execute).with(context)
        expect(throw_spy).to have_received(:call).with(task_result2)
      end

      it "stops execution on first breakpoint match" do
        throw_spy = instance_spy("ThrowHandler")
        allow(workflow_instance).to receive(:throw!) { |result| throw_spy.call(result) }

        workflow_instance.work

        expect(throw_spy).to have_received(:call).with(task_result2)
      end
    end
  end
end
