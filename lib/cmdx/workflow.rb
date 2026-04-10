# frozen_string_literal: true

module CMDx
  # Include in a Task subclass to declare a pipeline of child tasks
  # instead of implementing +#work+ directly.
  module Workflow

    def self.included(base)
      base.extend(ClassMethods)
      base.define_method(:work) { run_workflow }
    end

    # @return [void]
    #
    # @rbs () -> void
    def run_workflow
      pipeline = self.class.cmdx_workflow_pipeline
      chain = Chain.current
      trace = Trace.root

      Pipeline.call(pipeline, context, chain, trace, self.class.definition.on_failure)
    end

    module ClassMethods

      # @return [Boolean]
      #
      # @rbs () -> bool
      def cmdx_workflow?
        true
      end

      # @return [Array<Hash>]
      #
      # @rbs () -> Array[Hash[Symbol, untyped]]
      def cmdx_workflow_pipeline
        @cmdx_workflow_pipeline ||= []
      end

      # Declares a sequential child task.
      #
      # @param task_class [Class<Task>]
      # @param options [Hash]
      #
      # @rbs (Class task_class, **untyped options) -> void
      def task(task_class, **options)
        cmdx_workflow_pipeline << { task_class:, options: }
      end

      # Declares multiple tasks. Use +parallel: true+ for parallel execution.
      #
      # @param task_classes [Array<Class<Task>>]
      # @param parallel [Boolean]
      # @param options [Hash]
      #
      # @rbs (*Class task_classes, ?parallel: bool, **untyped options) -> void
      def tasks(*task_classes, parallel: false, **options)
        if parallel
          entries = task_classes.map { |tc| [tc, options] }
          cmdx_workflow_pipeline << { parallel: true, tasks: entries }
        else
          task_classes.each { |tc| task(tc, **options) }
        end
      end

    end

  end
end
