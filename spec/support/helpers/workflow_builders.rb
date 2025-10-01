# frozen_string_literal: true

module CMDx
  module Testing
    module WorkflowBuilders

      # Base

      def create_workflow_class(base: CMDx::Task, name: "AnonymousWorkflow", &)
        workflow_class = Class.new(base)
        workflow_class.include(CMDx::Workflow)
        workflow_class.define_singleton_method(:name) { @name ||= name.to_s + rand(9999).to_s.rjust(4, "0") }
        workflow_class.class_eval(&) if block_given?
        workflow_class
      end

      # Simple

      def create_successful_workflow(base: CMDx::Task, name: "SuccessfulWorkflow", &block)
        task1 = create_successful_task(base:, name: "SuccessfulTask1")
        task2 = create_nested_task(base:, strategy: :throw, status: :success)
        task3 = create_successful_task(base:, name: "SuccessfulTask3")

        create_workflow_class(base:, name:) do
          tasks task1, task2, task3

          class_eval(&block) if block_given?
        end
      end

      def create_skipping_workflow(base: CMDx::Task, name: "SkippingWorkflow", &block)
        pre_skip_task = create_successful_task(base:, name: "PreSkipTask")
        skipping_task = create_nested_task(base:, strategy: :throw, status: :skipped)
        post_skip_task = create_successful_task(base:, name: "PostSkipTask")

        create_workflow_class(base:, name:) do
          tasks pre_skip_task, skipping_task, post_skip_task

          class_eval(&block) if block_given?
        end
      end

      def create_failing_workflow(base: CMDx::Task, name: "FailingWorkflow", &block)
        pre_fail_task = create_successful_task(base:, name: "PreFailTask")
        failing_task = create_nested_task(base:, strategy: :throw, status: :failure)
        post_fail_task = create_successful_task(base:, name: "PostFailTask")

        create_workflow_class(base:, name:) do
          tasks pre_fail_task, failing_task, post_fail_task

          class_eval(&block) if block_given?
        end
      end

      def create_erroring_workflow(base: CMDx::Task, name: "ErroringWorkflow", &block)
        pre_error_task = create_successful_task(base:, name: "PreErrorTask")
        erroring_task = create_nested_task(base:, strategy: :raise, status: :error)
        post_error_task = create_successful_task(base:, name: "PostErrorTask")

        create_workflow_class(base:, name:) do
          tasks pre_error_task, erroring_task, post_error_task

          class_eval(&block) if block_given?
        end
      end

    end
  end
end
