# frozen_string_literal: true

module CMDx
  # Mixin that turns a {Task} subclass into a workflow: a pipeline of
  # ordered task groups run sequentially or in parallel. Defining `#work`
  # on a workflow is forbidden — `#work` is auto-generated to delegate to
  # {Pipeline}. Subclasses inherit the parent's pipeline (via dup).
  #
  # @see Pipeline
  module Workflow

    module ClassMethods

      # @api private
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@pipeline, pipeline.dup)
      end

      # @return [Array<ExecutionGroup>] declared groups, in order
      def pipeline
        @pipeline ||= []
      end

      # Declares a task group. With no arguments, returns the pipeline.
      # Tasks must be `Task` subclasses.
      #
      # @param tasks [Array<Class<Task>>]
      # @param options [Hash{Symbol => Object}]
      # @option options [:sequential, :parallel] :strategy (:sequential)
      # @option options [Integer] :pool_size parallel worker/fiber count
      # @option options [:threads, :fibers, #call] :executor (:threads) parallel
      #   dispatch backend. `:fibers` requires a `Fiber.scheduler` to be
      #   installed (e.g. `Async { ... }`). A custom callable accepting
      #   `jobs:, concurrency:, on_job:` may also be passed.
      # @option options [:last_write_wins, :deep_merge, :no_merge, #call] :merge_strategy
      #   (:last_write_wins) how successful parallel contexts are folded back
      #   into the workflow context. Merging happens in declaration order. A
      #   callable `->(workflow_context, result) { ... }` may be passed to
      #   implement custom behavior (e.g. namespacing by task name).
      # @option options [Boolean] :fail_fast (false) when `:parallel`, drain
      #   pending tasks on the first failure (in-flight tasks still finish)
      # @option options [Symbol, Proc, #call] :if
      # @option options [Symbol, Proc, #call] :unless
      # @return [Array<ExecutionGroup>] the full pipeline
      # @raise [DefinitionError] when called with options but no tasks
      # @raise [TypeError] when any element isn't a `Task` subclass
      def tasks(*tasks, **options)
        raise DefinitionError, "#{name}: cannot declare an empty task group" if tasks.empty?

        pipeline << ExecutionGroup.new(
          tasks:
            tasks.map do |task|
              next task if task.is_a?(Class) && (task <= Task)

              raise TypeError, "#{task.inspect} is not a Task"
            end,
          options:
        )
      end
      alias task tasks

      private

      # Forbids user-defined `work` on workflows; `Workflow#work` delegates
      # to {Pipeline}.
      #
      # @raise [ImplementationError] when a workflow defines `work`
      def method_added(method_name)
        return super unless method_name == :work

        raise ImplementationError, "cannot define #{name}##{method_name} in a workflow"
      end

    end

    # Immutable declaration of a task group.
    ExecutionGroup = Data.define(:tasks, :options)

    # @api private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Runs the workflow's pipeline. Not meant to be overridden.
    #
    # @return [void]
    def work
      Pipeline.execute(self)
    end

  end
end
