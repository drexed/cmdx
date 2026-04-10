# frozen_string_literal: true

module CMDx

  # Base error class for all CMDx exceptions.
  class Error < StandardError; end

  # Raised when a required method is not implemented by the developer.
  class UndefinedMethodError < Error; end

  # Raised when an attribute declaration is invalid.
  class AttributeError < Error; end

  # Raised when a configuration value is invalid.
  class ConfigurationError < Error; end

  # Raised when a coercion type is unknown.
  class UnknownCoercionError < Error; end

  # Raised when a validation type is unknown.
  class UnknownValidatorError < Error; end

  # Raised when middleware does not yield.
  class MiddlewareError < Error; end

  # Raised when a deprecation restriction is violated.
  class DeprecationError < Error; end

  # Raised for invalid return declarations.
  class ReturnError < Error; end

end
