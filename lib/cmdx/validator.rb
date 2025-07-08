# frozen_string_literal: true

module CMDx
  ##
  # Base class for CMDx validators that provides parameter validation capabilities.
  #
  # Validator components validate parameter values against specific rules and constraints.
  # Each validator must implement the `call` method which receives the parameter value
  # and validation options, returning nothing on success or raising validation errors.
  #
  # Validators are used extensively in parameter definitions to ensure data integrity
  # and business rule compliance before task execution begins.
  #
  # @example Basic validator implementation
  #   class EmailValidator < CMDx::Validator
  #     def call(value, options = {})
  #       return if value.to_s.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  #
  #       raise CMDx::ValidationError, "must be a valid email address"
  #     end
  #   end
  #
  # @example Validator with configurable options
  #   class LengthValidator < CMDx::Validator
  #     def call(value, options = {})
  #       min = options[:minimum] || 0
  #       max = options[:maximum] || Float::INFINITY
  #       length = value.to_s.length
  #
  #       if length < min
  #         raise CMDx::ValidationError, "must be at least #{min} characters"
  #       elsif length > max
  #         raise CMDx::ValidationError, "must be at most #{max} characters"
  #       end
  #     end
  #   end
  #
  # @example Conditional validator
  #   class PasswordValidator < CMDx::Validator
  #     def call(value, options = {})
  #       return unless options[:require_strong]
  #
  #       password = value.to_s
  #       errors = []
  #
  #       errors << "must contain uppercase letter" unless password.match?(/[A-Z]/)
  #       errors << "must contain lowercase letter" unless password.match?(/[a-z]/)
  #       errors << "must contain digit" unless password.match?(/\d/)
  #       errors << "must contain special character" unless password.match?(/[!@#$%^&*]/)
  #
  #       raise CMDx::ValidationError, errors.join(", ") if errors.any?
  #     end
  #   end
  #
  # @example Using validators in parameter definitions
  #   class CreateUserTask < CMDx::Task
  #     required :email, type: :string, validate: EmailValidator
  #     required :username, type: :string, validate: { length: { minimum: 3, maximum: 20 } }
  #     required :password, type: :string, validate: { password: { require_strong: true } }
  #   end
  #
  # @see Parameter Parameter validation integration
  # @see ParameterValidator Parameter validation orchestration
  # @see ValidationError Validation error handling
  # @since 1.0.0
  class Validator

    ##
    # Convenience class method for creating and calling validator instances.
    #
    # This method provides a shortcut for validator execution without requiring
    # explicit instantiation. It creates a new validator instance and immediately
    # calls it with the provided value and options.
    #
    # @param value [Object] the value to validate
    # @param options [Hash] validation options and configuration
    # @return [void] returns nothing on successful validation
    # @raise [ValidationError] if validation fails
    #
    # @example Direct validator usage
    #   EmailValidator.call("user@example.com")  # => nil (success)
    #   EmailValidator.call("invalid-email")     # => raises ValidationError
    #
    # @example With validation options
    #   LengthValidator.call("test", minimum: 5)  # => raises ValidationError
    #   LengthValidator.call("testing", minimum: 5)  # => nil (success)
    #
    # @since 1.0.0
    def self.call(value, options = {})
      new.call(value, options)
    end

    ##
    # Validates a value against the validator's rules and constraints.
    #
    # This method must be implemented by validator subclasses to define their
    # specific validation logic. The method should return nothing on successful
    # validation or raise a ValidationError with an appropriate message when
    # validation fails.
    #
    # @param value [Object] the value to validate
    # @param options [Hash] validation options and configuration
    # @return [void] returns nothing on successful validation
    # @raise [ValidationError] if validation fails
    # @raise [UndefinedCallError] if not implemented by subclass
    # @abstract Subclasses must implement this method
    #
    # @example Basic validation implementation
    #   def call(value, options = {})
    #     return if value.to_s.length >= (options[:minimum] || 0)
    #
    #     raise CMDx::ValidationError, "must be at least #{options[:minimum]} characters"
    #   end
    #
    # @example Complex validation with multiple checks
    #   def call(value, options = {})
    #     errors = []
    #
    #     errors << "cannot be blank" if value.to_s.strip.empty?
    #     errors << "must be numeric" unless value.to_s.match?(/^\d+$/)
    #     errors << "must be positive" if value.to_i <= 0
    #
    #     raise CMDx::ValidationError, errors.join(", ") if errors.any?
    #   end
    #
    # @since 1.0.0
    def call(_value, _options = {})
      raise UndefinedCallError, "call method not defined in #{self.class.name}"
    end

  end
end
