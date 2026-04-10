# frozen_string_literal: true

module CMDx

  # @abstract Base class for all CMDx exceptions.
  class Error < StandardError; end

  Exception = Error

  # @abstract Raised when a type coercion fails.
  class CoercionError < Error; end

  # @abstract Raised when a deprecated task is executed with `deprecate: :raise`.
  class DeprecationError < Error; end

  # @abstract Raised when a task is executed without defining a `work` method.
  class UndefinedMethodError < Error; end

  # @abstract Raised when a custom validator rejects a value.
  class ValidationError < Error; end

  # @abstract Base class for execution interruptions raised by `execute!`.
  #   Carries a `result` with full execution context.
  class Fault < Error

    attr_reader :result

    def initialize(message = nil, result: nil)
      @result = result
      super(message)
    end

    # @return [CMDx::Task, nil]
    def task
      result&.task
    end

    # @return [CMDx::Context, nil]
    def context
      result&.context
    end

    # @return [CMDx::Chain, nil]
    def chain
      result&.chain
    end

    # Matches faults originating from specific task classes.
    # @example
    #   rescue CMDx::FailFault.for?(MyTask, OtherTask) => e
    # @param classes [Array<Class>] task classes to match
    # @return [Module] module with `===` defined for rescue matching
    def self.for?(*classes)
      fault_class = self
      matcher = Object.new
      matcher.define_singleton_method(:===) do |fault|
        fault.is_a?(fault_class) && fault.task && classes.any? { |klass| fault.task.is_a?(klass) }
      end
      matcher
    end

    # Matches faults using custom block logic.
    # @example
    #   rescue CMDx::Fault.matches? { |f| f.context.amount > 1000 } => e
    # @yield [fault] block that receives the fault and returns truthy/falsy
    # @return [Object] object with `===` defined for rescue matching
    def self.matches?(&)
      fault_class = self
      matcher = Object.new
      matcher.define_singleton_method(:===) do |fault|
        fault.is_a?(fault_class) && yield(fault)
      end
      matcher
    end

  end

  # @abstract Raised when a task is skipped via `skip!` during `execute!`.
  class SkipFault < Fault; end

  # @abstract Raised when a task fails via `fail!`, validation errors,
  #   or exceptions during `execute!`.
  class FailFault < Fault; end

  # @abstract Raised when a task exceeds its timeout limit.
  #   Inherits from Interrupt so `rescue StandardError` won't catch it.
  class TimeoutError < Interrupt; end

end
