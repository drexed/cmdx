# frozen_string_literal: true

module CMDx
  # Base class for implementing validation functionality in parameter processing.
  #
  # Validators are used to validate parameter values during task execution to
  # ensure data integrity and business rule compliance. All validator implementations
  # must inherit from this class and implement the abstract call method.
  class Validator

    # Executes a validator by creating a new instance and calling it.
    #
    # @param value [Object] the value to be validated
    # @param options [Hash] optional validation configuration
    #
    # @return [Object] the result of the validation execution
    #
    # @raise [UndefinedCallError] when the validator subclass doesn't implement call
    #
    # @example Execute a validator on a value
    #   MyValidator.call("example", { min_length: 5 })
    def self.call(value, options = {})
      new.call(value, options)
    end

    # Abstract method that must be implemented by validator subclasses.
    #
    # This method contains the actual validation logic to be executed.
    # Subclasses must override this method to provide their specific
    # validation implementation.
    #
    # @param _value [Object] the value to be validated
    # @param _options [Hash] optional validation configuration
    #
    # @return [Object] the result of the validation execution
    #
    # @raise [UndefinedCallError] always raised in the base class
    #
    # @example Implement in a subclass
    #   def call(value, options)
    #     raise ValidationError, "Value too short" if value.length < options[:min_length]
    #   end
    def call(_value, _options = {})
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
