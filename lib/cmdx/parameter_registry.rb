# frozen_string_literal: true

module CMDx
  # Registry for managing parameter definitions within tasks.
  #
  # This registry maintains a collection of parameter definitions and provides
  # validation functionality to ensure all parameters are properly configured
  # and accessible on their associated tasks. It supports both flat and nested
  # parameter structures through recursive validation.
  class ParameterRegistry

    # @return [Array<Parameter>] array containing parameter definition objects
    attr_reader :registry

    # Initializes a new parameter registry with an empty parameter collection.
    #
    # @return [ParameterRegistry] a new parameter registry instance
    #
    # @example Creating a new registry
    #   registry = ParameterRegistry.new
    #   registry.registry #=> []
    def initialize
      @registry = []
    end

    # Creates a duplicate of the parameter registry with deep-copied parameters.
    #
    # This method creates a new registry instance with duplicated parameter
    # definitions, ensuring changes to the duplicate don't affect the original.
    #
    # @return [ParameterRegistry] a new registry instance with duplicated parameters
    #
    # @example Duplicate a registry
    #   original = ParameterRegistry.new
    #   duplicate = original.dup
    #   duplicate.object_id != original.object_id #=> true
    def dup
      new_registry = self.class.new
      new_registry.instance_variable_set(:@registry, registry.map(&:dup))
      new_registry
    end

    # Checks if all parameters in the registry are valid.
    #
    # @return [Boolean] true if all parameters are valid, false otherwise
    #
    # @example Check registry validity
    #   registry.valid? #=> true
    def valid?
      registry.all?(&:valid?)
    end

    # Validates all parameters in the registry against a task instance.
    #
    # This method ensures that each parameter is properly defined and accessible
    # on the provided task, including nested parameters through recursive validation.
    #
    # @param task [Task] the task instance to validate parameters against
    #
    # @return [void]
    #
    # @raise [NoMethodError] if a parameter method is not defined on the task
    #
    # @example Validate parameters against a task
    #   registry.validate!(task_instance)
    def validate!(task)
      registry.each { |p| recursive_validate!(task, p) }
    end

    # Converts the parameter registry to a hash representation.
    #
    # @return [Array<Hash>] array of parameter hash representations
    #
    # @example Convert registry to hash
    #   registry.to_h #=> [{name: :user_id, type: :integer}, {name: :email, type: :string}]
    def to_h
      registry.map(&:to_h)
    end

    # Converts the parameter registry to a string representation.
    #
    # @return [String] string representation of all parameters, joined by newlines
    #
    # @example Convert registry to string
    #   registry.to_s #=> "user_id: integer\nemail: string"
    def to_s
      registry.map(&:to_s).join("\n")
    end

    private

    # Recursively validates a parameter and its children against a task.
    #
    # @param task [Task] the task instance to validate the parameter against
    # @param parameter [Parameter] the parameter to validate
    #
    # @return [void]
    #
    # @raise [NoMethodError] if the parameter method is not defined on the task
    def recursive_validate!(task, parameter)
      task.send(parameter.method_name) # Make sure parameter is defined on task
      parameter.children.each { |child| recursive_validate!(task, child) }
    end

  end
end
