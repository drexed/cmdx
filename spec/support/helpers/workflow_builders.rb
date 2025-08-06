# frozen_string_literal: true

module CMDx
  module Testing
    module WorkflowBuilders

      def create_workflow_class(base: nil, name: "AnonymousWorkflow", &block)
        workflow_class = Class.new(base || CMDx::Task)
        workflow_class.include(CMDx::Workflow)
        workflow_class.define_singleton_method(:name) { name.to_s << rand(9999).to_s.rjust(4, "0") }
        workflow_class.class_eval(&block) if block_given?
        workflow_class
      end

      def create_successful_workflow(base: nil, name: "SuccessfulWorkflow", &block)
        create_workflow_class(name:, base:) do
          task create_successful_task(name: "SuccessfulTask1")
          tasks create_successful_task(name: "SuccessfulTask2"), create_successful_task(name: "SuccessfulTask3")

          class_eval(&block) if block_given?
        end
      end

      def create_skipping_workflow(base: nil, name: "SkippingWorkflow", &block)
        create_workflow_class(name:, base:) do
          task create_successful_task(name: "PreSkipTask")
          task create_skipping_task(name: "SkippingTask")
          task create_successful_task(name: "PostSkipTask")

          class_eval(&block) if block_given?
        end
      end

      def create_failing_workflow(base: nil, name: "FailingWorkflow", &block)
        create_workflow_class(name:, base:) do
          task create_successful_task(name: "PreFailTask")
          task create_failing_task(name: "FailingTask")
          task create_successful_task(name: "PostFailTask")

          class_eval(&block) if block_given?
        end
      end

      def create_erroring_workflow(base: nil, name: "ErroringWorkflow", &block)
        create_workflow_class(name:, base:) do
          task create_successful_task(name: "PreErrorTask")
          task create_erroring_task(name: "ErroringTask")
          task create_successful_task(name: "PostErrorTask")

          class_eval(&block) if block_given?
        end
      end

    end
  end
end
