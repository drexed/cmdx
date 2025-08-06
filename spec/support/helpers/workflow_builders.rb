# frozen_string_literal: true

module CMDx
  module Testing
    module WorkflowBuilders

      # Base

      def create_workflow_class(name: "AnonymousWorkflow", &block)
        workflow_class = Class.new(CMDx::Task)
        workflow_class.include(CMDx::Workflow)
        workflow_class.define_singleton_method(:name) { name.to_s + rand(9999).to_s.rjust(4, "0") }
        workflow_class.class_eval(&block) if block_given?
        workflow_class
      end

      # Simple

      def create_successful_workflow(name: "SuccessfulWorkflow", &block)
        task1 = create_successful_task(name: "SuccessfulTask1")
        task2 = create_successful_task(name: "SuccessfulTask2")
        task3 = create_successful_task(name: "SuccessfulTask3")

        create_workflow_class(name:) do
          tasks task1, task2, task3

          class_eval(&block) if block_given?
        end
      end

      def create_skipping_workflow(name: "SkippingWorkflow", &block)
        pre_skip_task = create_successful_task(name: "PreSkipTask")
        skipping_task = create_skipping_task(name: "SkippingTask")
        post_skip_task = create_successful_task(name: "PostSkipTask")

        create_workflow_class(name:) do
          tasks pre_skip_task, skipping_task, post_skip_task

          class_eval(&block) if block_given?
        end
      end

      def create_failing_workflow(name: "FailingWorkflow", &block)
        pre_fail_task = create_successful_task(name: "PreFailTask")
        failing_task = create_failing_task(name: "FailingTask")
        post_fail_task = create_successful_task(name: "PostFailTask")

        create_workflow_class(name:) do
          tasks pre_fail_task, failing_task, post_fail_task

          class_eval(&block) if block_given?
        end
      end

      def create_erroring_workflow(name: "ErroringWorkflow", &block)
        pre_error_task = create_successful_task(name: "PreErrorTask")
        erroring_task = create_erroring_task(name: "ErroringTask")
        post_error_task = create_successful_task(name: "PostErrorTask")

        create_workflow_class(name:) do
          tasks pre_error_task, erroring_task, post_error_task

          class_eval(&block) if block_given?
        end
      end

    end
  end
end
