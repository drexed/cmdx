# frozen_string_literal: true

module CMDx
  # Handles retry logic for task execution failures with configurable retry policies.
  #
  # The Repeator class manages retry attempts for failed task executions, including
  # exception filtering, retry counting, delay calculation, and logging of retry attempts.
  class Repeator

    attr_reader :task, :exception

    # @param task [CMDx::Task] The task instance to handle retries for
    #
    # @return [CMDx::Repeator] A new repeator instance
    #
    # @example
    #   repeator = CMDx::Repeator.new(my_task)
    def initialize(task)
      @task = task
    end

    # Determines if a task should be retried based on the exception and retry configuration.
    #
    # @param exception [Exception] The exception that occurred during task execution
    #
    # @return [Boolean] Whether the task should be retried
    #
    # @example
    #   if repeator.retry?(network_error)
    #     puts "Retrying task execution"
    #   end
    def retry?(exception)
      @exception = exception

      return false unless available_retries.positive? &&
                          remaining_retries.positive? &&
                          retriable_exception?

      task.result.metadata[:retries] += 1
      log_current_attempt
      delay_next_attempt

      true
    end

    private

    # Checks if the current exception is retriable based on task configuration.
    #
    # @return [Boolean] Whether the exception is retriable
    #
    # @example
    #   retriable_exception? # => true if exception matches retry_on settings
    def retriable_exception?
      exceptions = Array(task.class.settings[:retry_on] || StandardError)
      exceptions.any? { |e| exception.class <= e }
    end

    # Gets the total number of retries configured for the task.
    #
    # @return [Integer] The maximum number of retries allowed
    #
    # @example
    #   available_retries # => 3
    def available_retries
      (task.class.settings[:retries] || 0).to_i
    end

    # Gets the current number of retries already attempted.
    #
    # @return [Integer] The number of retries already performed
    #
    # @example
    #   current_retries # => 1
    def current_retries
      (task.result.metadata[:retries] ||= 0).to_i
    end

    # Calculates the number of retries remaining.
    #
    # @return [Integer] The number of retries left
    #
    # @example
    #   remaining_retries # => 2
    def remaining_retries
      available_retries - current_retries
    end

    # Delays the next retry attempt based on jitter configuration.
    def delay_next_attempt
      jitter = task.class.settings[:retry_jitter].to_f * current_retries
      sleep(jitter) if jitter.positive?
    end

    # Logs the current retry attempt with exception details.
    def log_current_attempt
      task.logger.warn do
        task.to_h.merge!(
          reason: "[#{exception.class}] #{exception.message}",
          remaining_retries:
        )
      end
    end

  end
end
