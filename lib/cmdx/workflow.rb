# frozen_string_literal: true

module CMDx
  # Compose multiple tasks into sequential or parallel pipelines.
  # Include in a Task subclass -- do NOT define a `work` method.
  #
  # @example
  #   class OnboardUser < CMDx::Task
  #     include CMDx::Workflow
  #
  #     task CreateProfile
  #     task SetupPreferences
  #     task SendWelcome, if: :email_enabled?
  #   end
  module Workflow

    def self.included(base)
      base.extend(ClassMethods)
      base.instance_variable_set(:@workflow_tasks, [])

      base.define_method(:work) do
        self.class.workflow_tasks.each do |group|
          break unless result.success? || !should_break?(group)

          if group[:strategy] == :parallel
            execute_parallel(group[:entries])
          else
            execute_sequential(group[:entries])
          end
        end
      end
    end

    module ClassMethods

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@workflow_tasks, workflow_tasks.map(&:dup))
      end

      # @return [Array<Hash>]
      def workflow_tasks
        @workflow_tasks ||= []
      end

      # Declare one or more tasks to run sequentially.
      #
      # @param task_classes [Array<Class>]
      # @param options [Hash] :if, :unless, :breakpoints, :strategy
      def task(*task_classes, **options)
        strategy = options.delete(:strategy) || :sequential
        entries = task_classes.map do |klass|
          {
            task_class: klass,
            if: options[:if],
            unless: options[:unless]
          }
        end

        workflow_tasks << {
          entries: entries,
          strategy: strategy,
          breakpoints: options[:breakpoints]
        }
      end
      alias tasks task

    end

    private

    def execute_sequential(entries)
      entries.each do |entry|
        break unless result.success? || !should_break_entry?(entry)
        next unless should_run?(entry)

        run_workflow_task(entry[:task_class])
      end
    end

    def execute_parallel(entries)
      runnable = entries.select { |e| should_run?(e) }
      return if runnable.empty?

      threads = runnable.map do |entry|
        ctx_copy = Context.build(context.to_h)
        Thread.new(entry, ctx_copy) do |ent, ctx|
          ent[:task_class].execute(ctx)
        end
      end

      threads.each do |thread|
        task_result = thread.value
        context.merge!(task_result.context.to_h)

        result.throw!(task_result) if task_result.failed?
      end
    end

    def run_workflow_task(task_class)
      task_result = task_class.execute(context)

      maybe_rollback_workflow_task(task_class, task_result)

      return unless task_result.failed? || (task_result.skipped? && should_break_on_skip?)

      result.throw!(task_result)
    end

    def maybe_rollback_workflow_task(_task_class, task_result)
      rollback_statuses = Array(self.class.task_settings.rollback_on)
      return unless rollback_statuses.include?(task_result.status)

      task_result.task.rollback if task_result.task.respond_to?(:rollback)
      task_result.mark_rolled_back!
    end

    def should_run?(entry)
      return false if entry[:if] && !Callable.evaluate(entry[:if], self)

      return false if entry[:unless] && Callable.evaluate(entry[:unless], self)

      true
    end

    def should_break?(group)
      breakpoints = group[:breakpoints] || Array(self.class.task_settings.workflow_breakpoints)
      breakpoints.include?(result.status)
    end

    def should_break_entry?(_entry)
      should_break?({ breakpoints: nil })
    end

    def should_break_on_skip?
      breakpoints = Array(self.class.task_settings.workflow_breakpoints)
      breakpoints.include?("skipped")
    end

  end
end
