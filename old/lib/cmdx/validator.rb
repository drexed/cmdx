# frozen_string_literal: true

module CMDx
  # Base class for implementing parameter validation functionality in task processing.
  #
  # Validators are used to validate parameter values against specific rules and constraints,
  # supporting both built-in validation types and custom validation logic. All validator
  # implementations must inherit from this class and implement the abstract call method.
  class Validator

    # Executes a validator by creating a new instance and calling it.
    #
    # @param value [Object] the value to be validated
    # @param options [Hash] additional options for the validation
    #
    # @return [Object] the validated value if validation passes
    #
    # @raise [UndefinedCallError] when the validator subclass doesn't implement call
    # @raise [ValidationError] when validation fails
    #
    # @example Execute a validator on a value
    #   PresenceValidator.call("some_value") #=> "some_value"
    #
    # @example Execute with options
    #   NumericValidator.call(42, greater_than: 10) #=> 42
    def self.call(value, options = {})
      new.call(value, options)
    end

    # Abstract method that must be implemented by validator subclasses.
    #
    # This method contains the actual validation logic to verify the input
    # value meets the specified criteria. Subclasses must override this method
    # to provide their specific validation implementation.
    #
    # @param value [Object] the value to be validated
    # @param options [Hash] additional options for the validation
    #
    # @return [Object] the validated value if validation passes
    #
    # @raise [UndefinedCallError] always raised in the base class
    # @raise [ValidationError] when validation fails in subclass implementations
    #
    # @example Implement in a subclass
    #   class BlankValidator < CMDx::Validator
    #     def call(value, options = {})
    #       if value.nil? || value.empty?
    #         raise ValidationError, options[:message] || "Value cannot be blank"
    #       end
    #     end
    #   end
    def call(value, options = {}) # rubocop:disable Lint/UnusedMethodArgument
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
