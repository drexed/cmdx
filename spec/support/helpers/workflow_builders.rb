# frozen_string_literal: true

module CMDx
  module Testing
    module WorkflowBuilders

      def create_workflow_class(base: nil, name: "AnonymousWorkflow", &block)
        workflow_class = Class.new(base || CMDx::Workflow)
        workflow_class.define_singleton_method(:name) do
          hash = rand(10_000).to_s.rjust(4, "0")
          "#{name}#{hash}"
        end
        workflow_class.class_eval(&block) if block_given?
        workflow_class
      end

      def create_simple_workflow(tasks:, base: nil, name: "SimpleWorkflow", &block)
        create_workflow_class(name:, base:) do
          Array(tasks).each { |task| process task }

          class_eval(&block) if block_given?
        end
      end

      def create_successful_workflow(base: nil, name: "SuccessfulWorkflow", &block)
        create_workflow_class(name:, base:) do
          process create_successful_task(name: "SuccessfulTask1")
          process create_successful_task(name: "SuccessfulTask2")
          process create_successful_task(name: "SuccessfulTask3")

          class_eval(&block) if block_given?
        end
      end

      def create_skipping_workflow(base: nil, name: "SkippingWorkflow", &block)
        create_workflow_class(name:, base:) do
          process create_successful_task(name: "PreSkipTask")
          process create_skipping_task(name: "SkippingTask")
          process create_successful_task(name: "PostSkipTask")

          class_eval(&block) if block_given?
        end
      end

      def create_failing_workflow(base: nil, name: "FailingWorkflow", &block)
        create_workflow_class(name:, base:) do
          process create_successful_task(name: "PreFailTask")
          process create_failing_task(name: "FailingTask")
          process create_successful_task(name: "PostFailTask")

          class_eval(&block) if block_given?
        end
      end

      def create_erroring_workflow(base: nil, name: "ErroringWorkflow", &block)
        create_workflow_class(name:, base:) do
          process create_successful_task(name: "PreErrorTask")
          process create_erroring_task(name: "ErroringTask")
          process create_successful_task(name: "PostErrorTask")

          class_eval(&block) if block_given?
        end
      end

    end
  end
end
