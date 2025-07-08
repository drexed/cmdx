# frozen_string_literal: true

module CMDx
  ##
  # Base class for CMDx callbacks that provides lifecycle execution points.
  #
  # Callback components can wrap or observe task execution at specific lifecycle
  # points like before validation, on success, after execution, etc.
  # Each callback must implement the `call` method which receives the
  # task instance and callback context.
  #
  # @example Basic callback implementation
  #   class LoggingCallback < CMDx::Callback
  #     def call(task, type)
  #       puts "Executing #{type} callback for #{task.class.name}"
  #       task.logger.info("Callback executed: #{type}")
  #     end
  #   end
  #
  # @example Callback with initialization parameters
  #   class NotificationCallback < CMDx::Callback
  #     def initialize(channels)
  #       @channels = channels
  #     end
  #
  #     def call(task, type)
  #       return unless type == :on_success
  #
  #       @channels.each do |channel|
  #         NotificationService.send(channel, "Task #{task.class.name} completed")
  #       end
  #     end
  #   end
  #
  # @example Conditional callback execution
  #   class ErrorReportingCallback < CMDx::Callback
  #     def call(task, type)
  #       return unless type == :on_failure
  #       return unless task.result.failed?
  #
  #       ErrorReporter.notify(
  #         task.errors.full_messages.join(", "),
  #         context: task.context.to_h
  #       )
  #     end
  #   end
  #
  # @see CallbackRegistry Callback management
  # @see Task Callback integration
  # @since 1.0.0
  class Callback

    ##
    # Class-level convenience method for creating and calling a callback.
    #
    # This method creates a new instance of the callback class and immediately
    # calls it with the provided task and type. This is useful for stateless
    # callbacks that don't need to maintain state between calls.
    #
    # @param task [Task] The task instance being executed
    # @param type [Symbol] The type of callback being executed
    # @return [void] The result of the callback execution
    #
    # @example Using class-level call
    #   LoggingCallback.call(task, :on_success)
    #
    # @since 1.1.0
    def self.call(task, type)
      new.call(task, type)
    end

    ##
    # Executes the callback logic.
    #
    # This method must be implemented by subclasses to define the callback
    # behavior. The method receives the task instance and the callback type
    # being executed.
    #
    # @param task [Task] the task instance being executed
    # @param type [Symbol] the type of callback being executed
    # @return [void]
    # @abstract Subclasses must implement this method
    def call(_task, _type)
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
