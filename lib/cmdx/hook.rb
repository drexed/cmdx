# frozen_string_literal: true

module CMDx
  ##
  # Base class for CMDx hooks that provides lifecycle execution points.
  #
  # Hook components can wrap or observe task execution at specific lifecycle
  # points like before validation, on success, after execution, etc.
  # Each hook must implement the `call` method which receives the
  # task instance and hook context.
  #
  # @example Basic hook implementation
  #   class LoggingHook < CMDx::Hook
  #     def call(task, hook_type)
  #       puts "Executing #{hook_type} hook for #{task.class.name}"
  #       task.logger.info("Hook executed: #{hook_type}")
  #     end
  #   end
  #
  # @example Hook with initialization parameters
  #   class NotificationHook < CMDx::Hook
  #     def initialize(channels)
  #       @channels = channels
  #     end
  #
  #     def call(task, hook_type)
  #       return unless hook_type == :on_success
  #
  #       @channels.each do |channel|
  #         NotificationService.send(channel, "Task #{task.class.name} completed")
  #       end
  #     end
  #   end
  #
  # @example Conditional hook execution
  #   class ErrorReportingHook < CMDx::Hook
  #     def call(task, hook_type)
  #       return unless hook_type == :on_failure
  #       return unless task.result.failed?
  #
  #       ErrorReporter.notify(
  #         task.errors.full_messages.join(", "),
  #         context: task.context.to_h
  #       )
  #     end
  #   end
  #
  # @see HookRegistry Hook management
  # @see Task Hook integration
  # @since 1.0.0
  class Hook

    ##
    # Executes the hook logic.
    #
    # This method must be implemented by subclasses to define the hook
    # behavior. The method receives the task instance and the hook type
    # being executed.
    #
    # @param task [Task] the task instance being executed
    # @param hook_type [Symbol] the type of hook being executed
    # @return [void]
    # @abstract Subclasses must implement this method
    def call(_task, _hook_type)
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
