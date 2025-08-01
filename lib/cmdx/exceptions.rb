# frozen_string_literal: true

module CMDx

  # TODO: see what exceptions to keep and what to remove

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

  # Raised when attempting to delegate a method to a missing object.
  #
  # This error occurs when trying to delegate a method to an object that does not
  # respond to the method. It indicates that the target object is not available
  # or does not support the requested method.
  DelegationError = Class.new(Error)

  # Raised when a deprecated task is used.
  #
  # This error occurs when a deprecated task is called. It indicates that the
  # task is no longer supported and should be replaced with a newer alternative.
  DeprecationError = Class.new(Error)

  # Raised when an abstract method is called without being implemented.
  #
  # This error occurs when a subclass fails to implement required abstract methods
  # such as call methods in validators, callbacks, or middleware. It indicates
  # incomplete implementation of required functionality.
  UndefinedCallError = Class.new(Error)

  # Raised when attempting to delegate a method to a missing object.
  #
  # This error occurs when trying to delegate a method to an object that does not
  # respond to the method. It indicates that the target object is not available
  # or does not support the requested method.
  UndefinedSourceError = Class.new(Error)

  # Raised when attempting to use an unregistered callback.
  #
  # This error occurs when trying to reference a callback that hasn't been
  # registered in the callback registry. It indicates that the callback name
  # is not recognized or was misspelled.
  UnknownCallbackError = Class.new(Error)

  # Raised when attempting to use an unregistered coercion type.
  #
  # This error occurs when trying to use a parameter type that doesn't have
  # a corresponding coercion handler registered. It indicates that the specified
  # type is not supported by the coercion system.
  UnknownCoercionError = Class.new(Error)

  # Raised when attempting to use an invalid deprecated setting.
  #
  # This error occurs when trying to use an invalid deprecated setting. It
  # indicates that the specified setting is not supported by the deprecation
  # system.
  UnknownDeprecationError = Class.new(Error)

  # Raised when attempting to use an unregistered validator.
  #
  # This error occurs when trying to reference a validator that hasn't been
  # registered in the validator registry. It indicates that the validator name
  # is not recognized or was misspelled.
  UnknownValidatorError = Class.new(Error)

  # Raised when parameter validation fails during task execution.
  #
  # This error occurs when a parameter value doesn't meet the validation criteria
  # defined by the validator. It indicates that the provided value violates
  # business rules or data integrity constraints.
  ValidationError = Class.new(Error)

end
