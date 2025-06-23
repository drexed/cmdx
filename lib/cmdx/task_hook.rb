# frozen_string_literal: true

module CMDx
  ##
  # TaskHook provides the execution mechanism for task lifecycle hooks.
  # It handles the conditional execution of hook callables based on task state
  # and hook options, supporting both method references and callable objects.
  #
  # Hooks are executed in a specific order during task execution:
  # 1. before_execution
  # 2. on_executing
  # 3. before_validation
  # 4. after_validation
  # 5. on_[complete, interrupted] (based on execution state)
  # 6. on_executed (if task was executed)
  # 7. on_[success, skipped, failed] (based on execution status)
  # 8. on_good / on_bad (based on success/failure)
  # 9. after_execution
  #
  # @example Basic hook execution
  #   class MyTask < CMDx::Task
  #     before_validation :check_permissions
  #     on_success :log_success
  #     on_failure :alert_admin, if: :critical?
  #   end
  #
  # @example Hook with conditions
  #   class ProcessOrderTask < CMDx::Task
  #     after_execution :cleanup_temp_files, unless: :keep_files?
  #     on_failure :retry_later, if: -> { retries < 3 }
  #   end
  #
  # @see Task Task class for hook definitions
  # @since 1.0.0
  module TaskHook

    module_function

    ##
    # Executes all hooks registered for a specific hook type on the given task.
    # Each hook is evaluated for its conditions (if/unless) before execution.
    #
    # Hook callables can be:
    # - Symbol: method name to call on the task
    # - Proc/Lambda: callable object executed in task context
    # - Any object responding to #call
    #
    # @param task [Task] the task instance to execute hooks on
    # @param hook [Symbol] the hook type to execute (e.g., :before_validation, :on_success)
    # @return [void]
    #
    # @example Hook execution with conditions
    #   # Only executes if task.critical? returns true
    #   TaskHook.call(task, :on_failure) # where task has on_failure :alert, if: :critical?
    #
    # @example Multiple hooks for same event
    #   # Executes all registered hooks in order
    #   class MyTask < CMDx::Task
    #     on_success :log_success
    #     on_success :send_notification
    #     on_success -> { update_metrics }
    #   end
    def call(task, hook)
      Array(task.class.cmd_hooks[hook]).each do |callables, options|
        next unless task.__cmdx_eval(options)

        hooks = Array(callables)
        hooks.each { |h| task.__cmdx_try(h) }
      end
    end

  end
end
