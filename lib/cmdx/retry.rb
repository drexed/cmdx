# frozen_string_literal: true

module CMDx
  # Manages retry logic and state for task execution.
  #
  # The Retry class tracks retry availability, attempt counts, and
  # remaining retries for a given task. It also resolves exception
  # matching and computes wait times using configurable jitter strategies.
  class Retry

    # Returns the task instance associated with this retry.
    #
    # @return [Task] the task being retried
    #
    # @example
    #   retry_instance.task # => #<CreateUser ...>
    #
    # @rbs @task: Task
    attr_reader :task

    # Creates a new Retry instance for the given task.
    #
    # @param task [Task] the task to manage retries for
    #
    # @return [Retry] a new Retry instance
    #
    # @example
    #   retry_instance = Retry.new(task)
    #
    # @rbs (Task task) -> void
    def initialize(task)
      @task = task
    end

    # Returns the total number of retries configured for the task.
    #
    # @return [Integer] the configured retry count
    #
    # @example
    #   retry_instance.available # => 3
    #
    # @rbs () -> Integer
    def available
      Integer(task.class.settings.retries || 0)
    end

    # Checks if the task has any retries configured.
    #
    # @return [Boolean] true if retries are configured
    #
    # @example
    #   retry_instance.available? # => true
    #
    # @rbs () -> bool
    def available?
      available.positive?
    end

    # Returns the number of retry attempts already made.
    #
    # @return [Integer] the current retry attempt count
    #
    # @example
    #   retry_instance.attempts # => 1
    #
    # @rbs () -> Integer
    def attempts
      Integer(task.result.retries || 0)
    end

    # Checks if the task has been retried at least once.
    #
    # @return [Boolean] true if at least one retry has occurred
    #
    # @example
    #   retry_instance.retried? # => true
    #
    # @rbs () -> bool
    def retried?
      attempts.positive?
    end

    # Returns the number of retries still available.
    #
    # @return [Integer] the remaining retry count
    #
    # @example
    #   retry_instance.remaining # => 2
    #
    # @rbs () -> Integer
    def remaining
      available - attempts
    end

    # Checks if there are retries still available.
    #
    # @return [Boolean] true if remaining retries exist
    #
    # @example
    #   retry_instance.remaining? # => true
    #
    # @rbs () -> bool
    def remaining?
      remaining.positive?
    end

    # Returns the list of exception classes eligible for retry.
    #
    # @return [Array<Class>] exception classes that trigger a retry
    #
    # @example
    #   retry_instance.exceptions # => [StandardError, CMDx::TimeoutError]
    #
    # @rbs () -> Array[Class]
    def exceptions
      @exceptions ||= Utils::Wrap.array(
        task.class.settings.retry_on ||
        [StandardError, CMDx::TimeoutError]
      )
    end

    # Checks if the given exception matches any configured retry exception.
    #
    # @param exception [Exception] the exception to check
    #
    # @return [Boolean] true if the exception qualifies for retry
    #
    # @example
    #   retry_instance.exception?(RuntimeError.new("fail")) # => true
    #
    # @rbs (Exception exception) -> bool
    def exception?(exception)
      exceptions.any? { |e| exception.class <= e }
    end

    # Computes the wait time before the next retry attempt.
    #
    # Supports multiple jitter strategies: a Symbol calls a task method,
    # a Proc is evaluated in the task instance context, a callable object
    # receives the task and attempts, and a Numeric is multiplied by the
    # attempt count.
    #
    # @return [Float] the wait duration in seconds
    #
    # @example With numeric jitter (0.5 * attempts)
    #   retry_instance.wait # => 1.0
    # @example With symbol jitter referencing a task method
    #   retry_instance.wait # => 2.5
    #
    # @rbs () -> Float
    def wait
      jitter = task.class.settings.retry_jitter

      if jitter.is_a?(Symbol)
        task.send(jitter, attempts)
      elsif jitter.is_a?(Proc)
        task.instance_exec(attempts, &jitter)
      elsif jitter.respond_to?(:call)
        jitter.call(task, attempts)
      else
        jitter.to_f * attempts
      end.to_f
    end

  end
end
