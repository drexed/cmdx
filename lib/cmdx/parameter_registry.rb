# frozen_string_literal: true

module CMDx
  # Registry for managing parameter definitions and validation within tasks.
  #
  # This registry handles the storage and validation of parameter definitions,
  # including nested parameter structures and recursive validation logic.
  class ParameterRegistry

    # The internal array storing parameter definitions.
    #
    # @return [Array] array containing parameter definition objects
    attr_reader :registry

    # Initializes a new parameter registry.
    #
    # @return [ParameterRegistry] a new parameter registry instance
    #
    # @example Creating an empty registry
    #   ParameterRegistry.new
    def initialize
      @registry = []
    end

    # Creates a deep copy of the parameter registry.
    #
    # @return [ParameterRegistry] a new registry instance with duplicated parameters
    #
    # @example Duplicating a registry
    #   original = ParameterRegistry.new
    #   copy = original.dup
    def dup
      new_registry = self.class.new
      new_registry.instance_variable_set(:@registry, registry.map(&:dup))
      new_registry
    end

    # Checks if all parameters in the registry are valid.
    #
    # @return [Boolean] true if all parameters are valid, false otherwise
    #
    # @example Checking registry validity
    #   registry.valid?
    #   # => true
    def valid?
      registry.all?(&:valid?)
    end

    # Validates all parameters in the registry against a task instance.
    #
    # @param task [Task] the task instance to validate parameters against
    #
    # @return [void]
    #
    # @example Validating parameters
    #   registry.validate!(task)
    def validate!(task)
      registry.each { |p| recursive_validate!(task, p) }
    end

    # Returns a hash representation of the registry.
    #
    # @return [Hash] serialized hash representation of all parameters
    #
    # @example Getting registry hash
    #   registry.to_h
    #   # => { name: { type: :string, required: true }, age: { type: :integer } }
    def to_h
      ParametersSerializer.call(registry)
    end

    # Returns a string representation of the registry.
    #
    # @return [String] formatted string representation of all parameters
    #
    # @example Getting registry string
    #   registry.to_s
    #   # => "name (string, required), age (integer)"
    def to_s
      ParametersInspector.call(registry)
    end

    private

    # Recursively validates a parameter and its children against a task.
    #
    # @param task [Task] the task instance to validate against
    # @param parameter [Parameter] the parameter to validate
    #
    # @return [void]
    #
    # @example Recursive validation (internal use)
    #   recursive_validate!(task, parameter)
    def recursive_validate!(task, parameter)
      task.send(parameter.method_name) # Make sure parameter is defined on task
      parameter.children.each { |child| recursive_validate!(task, child) }
    end

  end
end
