# frozen_string_literal: true

module CMDx
  # Base class for implementing parameter coercion functionality in task processing.
  #
  # Coercions are used to convert parameter values from one type to another during
  # task execution, enabling automatic type conversion and normalization. All coercion
  # implementations must inherit from this class and implement the abstract call method.
  class Coercion

    # Executes a coercion by creating a new instance and calling it.
    #
    # @param value [Object] the value to be coerced
    # @param options [Hash] additional options for the coercion
    #
    # @return [Object] the coerced value
    #
    # @raise [UndefinedCallError] when the coercion subclass doesn't implement call
    # @raise [CoercionError] when coercion fails in subclass implementations
    #
    # @example Execute a coercion on a value
    #   StringCoercion.call(123) #=> "123"
    #
    # @example Execute with options
    #   CustomCoercion.call("value", strict: true) #=> processed_value
    def self.call(value, options = {})
      new.call(value, options)
    end

    # Abstract method that must be implemented by coercion subclasses.
    #
    # This method contains the actual coercion logic to convert the input
    # value to the desired type. Subclasses must override this method
    # to provide their specific coercion implementation.
    #
    # @param value [Object] the value to be coerced (unused in base class)
    # @param options [Hash] additional options for the coercion (unused in base class)
    #
    # @return [Object] the coerced value
    #
    # @raise [UndefinedCallError] always raised in the base class
    # @raise [CoercionError] when coercion fails in subclass implementations
    #
    # @example Implement in a subclass
    #   class StringCoercion < CMDx::Coercion
    #     def call(value, _options = {})
    #       String(value)
    #     rescue ArgumentError, TypeError
    #       raise CoercionError, "could not coerce into a string"
    #     end
    #   end
    def call(value, options = {}) # rubocop:disable Lint/UnusedMethodArgument
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
