# frozen_string_literal: true

module CMDx
  # Module providing workflow DSL for orchestrating multiple tasks.
  #
  # @example
  #   class OnboardUser < CMDx::Task
  #     include CMDx::Workflow
  #
  #     task CreateAccount
  #     task SendWelcomeEmail, on_failure: :skip
  #     tasks CreateProfile, SetupPreferences, parallel: true
  #   end
  module Workflow

    # @rbs (untyped base) -> void
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level DSL for declaring workflow steps.
    module ClassMethods

      # @return [Array<Hash>] ordered list of task entries
      #
      # @rbs () -> Array[Hash[Symbol, untyped]]
      def workflow_entries
        @workflow_entries ||= if superclass.respond_to?(:workflow_entries)
                                superclass.workflow_entries.dup
                              else
                                []
                              end
      end

      # Declares a single task step in the workflow.
      #
      # @param task_class [Class] the task class
      # @param options [Hash] execution options (:on_failure, :if, :unless)
      #
      # @rbs (untyped task_class, **untyped options) -> void
      def task(task_class, **options)
        workflow_entries << { task: task_class, options: }
      end

      # Declares parallel task steps in the workflow.
      #
      # @param task_classes [Array<Class>] task classes to run in parallel
      # @param options [Hash] execution options (:pool_size, :on_failure)
      #
      # @rbs (*untyped task_classes, **untyped options) -> void
      def tasks(*task_classes, **options)
        entries = task_classes.map { |tc| { task: tc, options: } }
        workflow_entries << { parallel: true, tasks: entries }
      end

    end

    # Override work to execute the workflow pipeline (must be public; Runtime invokes it).
    #
    # @rbs () -> void
    def work
      entries = self.class.workflow_entries
      chain = Chain.current || Chain.new(dry_run: dry_run?)
      Chain.current = chain

      Pipeline.call(entries, context, chain)
    end

  end
end
