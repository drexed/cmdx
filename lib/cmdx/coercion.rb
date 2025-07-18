# frozen_string_literal: true

module CMDx
  # Base class for implementing type coercion functionality in parameter processing.
  #
  # Coercions are used to convert parameter values from one type to another,
  # supporting both built-in types and custom coercion logic. All coercion
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
    #
    # @example Execute a coercion on a value
    #   IntegerCoercion.call("42")
    #   #=> 42
    def self.call(value, options = {})
      new.call(value, options)
    end

    # Abstract method that must be implemented by coercion subclasses.
    #
    # This method contains the actual coercion logic to convert the input
    # value to the desired type. Subclasses must override this method to
    # provide their specific coercion implementation.
    #
    # @param _value [Object] the value to be coerced
    # @param _options [Hash] additional options for the coercion
    #
    # @return [Object] the coerced value
    #
    # @raise [UndefinedCallError] always raised in the base class
    #
    # @example Implement in a subclass
    #   def call(value, options = {})
    #     Integer(value)
    #   end
    def call(_value, _options = {})
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
