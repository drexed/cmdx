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
      # @param subclass [Class] newly defined workflow subclass
      # @return [void]
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
      # @option options [:last_write_wins, :deep_merge, :no_merge, #call] :merger
      #   (:last_write_wins) how successful parallel contexts are folded back
      #   into the workflow context. Merging happens in declaration order. A
      #   callable `->(workflow_context, result) { ... }` may be passed to
      #   implement custom behavior (e.g. namespacing by task name).
      # @option options [Boolean] :continue_on_failure (false) when `true`,
      #   run every task in the group to completion (even after a failure)
      #   and aggregate all failures into the workflow's `errors`. Each
      #   failed result's `errors` are merged in with keys namespaced as
      #   `"TaskClass.input"`; failures with no errors entries (bare
      #   `fail!("reason")`) record under `"TaskClass.<status>"` (e.g.
      #   `"MyTask.failed"`) with `result.reason` as the message (falling
      #   back to the localized `cmdx.reasons.unspecified` string when
      #   `reason` is nil). The pipeline still halts after the group with
      #   the first failure (declaration order) as the signal origin.
      #   Applies to both `:sequential` and `:parallel` strategies. When
      #   `false` (default), `:sequential` halts on the first failure and
      #   `:parallel` cancels pending tasks (in-flight tasks still finish).
      # @option options [Symbol, Proc, #call] :if
      # @option options [Symbol, Proc, #call] :unless
      # @return [Array<ExecutionGroup>] the full pipeline
      # @raise [DefinitionError] when called with options but no tasks
      # @raise [TypeError] when any element isn't a `Task` subclass
      def tasks(*tasks, **options)
        if tasks.empty?
          raise DefinitionError,
            "#{name}: cannot declare an empty task group; pass at least one Task subclass. " \
            "See https://drexed.github.io/cmdx/workflows/"
        end

        pipeline << ExecutionGroup.new(
          tasks:
            tasks.map do |task|
              next task if task.is_a?(Class) && (task <= Task)

              raise TypeError,
                "#{task.inspect} is not a Task subclass. " \
                "See https://drexed.github.io/cmdx/workflows/"
            end,
          options:
        )
      end
      alias task tasks

      private

      # Forbids user-defined `work` on workflows; `Workflow#work` delegates
      # to {Pipeline}.
      #
      # @param method_name [Symbol] hook name reported by Ruby
      # @return [void]
      # @raise [ImplementationError] when a workflow defines `work`
      def method_added(method_name)
        return super unless method_name == :work

        raise ImplementationError,
          "cannot define #{name}##{method_name} in a workflow; #work is auto-generated to delegate to Pipeline. " \
          "See https://drexed.github.io/cmdx/workflows/"
      end

    end

    # Immutable declaration of a task group.
    ExecutionGroup = Data.define(:tasks, :options)

    # @api private
    # @param base [Class] task class including this mixin
    # @return [void]
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
