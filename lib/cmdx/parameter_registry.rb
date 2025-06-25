# frozen_string_literal: true

module CMDx
  # Parameter collection class for managing multiple parameter definitions.
  #
  # The ParameterRegistry class extends Array to provide specialized functionality for
  # managing collections of Parameter instances within CMDx tasks. It handles
  # validation coordination, serialization, and inspection of parameter groups.
  #
  # @example Basic parameter collection usage
  #   parameter_registry = ParameterRegistry.new
  #   parameter_registry << Parameter.new(:user_id, klass: Task, type: :integer)
  #   parameter_registry << Parameter.new(:email, klass: Task, type: :string)
  #   parameter_registry.valid?  # => true (if all parameters are valid)
  #
  # @example Parameter collection validation
  #   parameter_registry.validate!(task_instance)  # Validates all parameters
  #   parameter_registry.invalid?  # => true if any parameter failed validation
  #
  # @example Parameter collection serialization
  #   parameter_registry.to_h  # => Array of parameter hash representations
  #   parameter_registry.to_s  # => Human-readable parameter descriptions
  #
  # @see CMDx::Parameter Individual parameter definitions
  # @see CMDx::Task Task parameter integration
  class ParameterRegistry < Array

    # Checks if any parameters in the collection are invalid.
    #
    # @return [Boolean] true if any parameter has validation errors, false otherwise
    #
    # @example
    #   parameter_registry.invalid?  # => true if validation errors exist
    def invalid?
      !valid?
    end

    # Checks if all parameters in the collection are valid.
    #
    # @return [Boolean] true if all parameters are valid, false otherwise
    #
    # @example
    #   parameter_registry.valid?  # => true if no validation errors exist
    def valid?
      all?(&:valid?)
    end

    # Validates all parameters in the collection against a task instance.
    #
    # Recursively validates each parameter and its children by calling the
    # parameter accessor methods on the task instance, which triggers
    # value resolution, coercion, and validation.
    #
    # @param task [CMDx::Task] The task instance to validate parameters against
    # @return [void]
    #
    # @example Validating parameters
    #   task = ProcessOrderTask.new
    #   parameter_registry.validate!(task)  # Validates all parameters
    #
    # @example Validation with nested parameters
    #   # Validates parent parameters and all nested child parameters
    #   parameter_registry.validate!(task_with_nested_params)
    def validate!(task)
      each { |p| recursive_validate!(task, p) }
    end

    # Converts the parameter collection to a hash representation.
    #
    # Serializes all parameters in the collection to their hash representations
    # using the ParametersSerializer.
    #
    # @return [Array<Hash>] Array of serialized parameter data
    #
    # @example
    #   parameter_registry.to_h
    #   # => [
    #   #   {
    #   #     source: :context,
    #   #     name: :user_id,
    #   #     type: :integer,
    #   #     required: true,
    #   #     options: {},
    #   #     children: []
    #   #   },
    #   #   { ... }
    #   # ]
    def to_h
      ParametersSerializer.call(self)
    end
    alias to_a to_h

    # Converts the parameter collection to a string representation.
    #
    # Creates a human-readable string representation of all parameters
    # in the collection using the ParametersInspector.
    #
    # @return [String] Multi-line parameter descriptions
    #
    # @example
    #   parameter_registry.to_s
    #   # => "Parameter: name=user_id type=integer source=context required=true
    #   #     Parameter: name=email type=string source=context required=false"
    def to_s
      ParametersInspector.call(self)
    end

    private

    # Recursively validates a parameter and all its children.
    #
    # Calls the parameter accessor method on the task to trigger validation,
    # then recursively validates all child parameters for nested parameter
    # structures.
    #
    # @param task [CMDx::Task] The task instance to validate against
    # @param parameter [CMDx::Parameter] The parameter to validate
    # @return [void]
    def recursive_validate!(task, parameter)
      task.send(parameter.method_name)
      parameter.children.each { |cp| recursive_validate!(task, cp) }
    end

  end
end
