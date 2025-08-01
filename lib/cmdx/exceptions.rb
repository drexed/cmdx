# frozen_string_literal: true

module CMDx

  # Base exception class for all CMDx-related errors.
  #
  # This serves as the root exception class for all errors raised by the CMDx
  # framework. It inherits from StandardError and provides a common base for
  # handling CMDx-specific exceptions.
  Error = Class.new(StandardError)

  # Raised when parameter coercion fails during task execution.
  #
  # This error occurs when a parameter value cannot be converted to the expected
  # type using the registered coercion handlers. It indicates that the provided
  # value is incompatible with the parameter's defined type.
  CoercionError = Class.new(Error)

  # Raised when a deprecated task is used.
  #
  # This error occurs when a deprecated task is called. It indicates that the
  # task is no longer supported and should be replaced with a newer alternative.
  DeprecationError = Class.new(Error)

  # Raised when an abstract method is called without being implemented.
  #
  # This error occurs when a subclass fails to implement required abstract
  # methods such as execute in tasks. It indicates incomplete implementation
  # of required functionality.
  UndefinedMethodError = Class.new(Error)

  # Raised when parameter validation fails during task execution.
  #
  # This error occurs when a parameter value doesn't meet the validation criteria
  # defined by the validator. It indicates that the provided value violates
  # business rules or data integrity constraints.
  ValidationError = Class.new(Error)

end
