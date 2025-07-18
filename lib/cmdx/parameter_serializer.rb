# frozen_string_literal: true

module CMDx
  # Parameter serialization utilities for converting parameter objects to hash representations.
  #
  # ParameterSerializer provides functionality to convert parameter definition objects
  # into structured hash format for serialization, introspection, and data exchange.
  # It extracts essential parameter metadata including source context, method names,
  # type information, requirement status, options, and nested child parameters.
  module ParameterSerializer

    module_function

    # Converts a parameter object into a hash representation for serialization.
    #
    # This method extracts key metadata from a parameter definition and structures
    # it into a hash format suitable for serialization, storage, or transmission.
    # Child parameters are recursively serialized to maintain nested structure.
    #
    # @param parameter [CMDx::Parameter] the parameter object to serialize
    #
    # @return [Hash] a hash containing the parameter's metadata and configuration
    # @option return [Symbol] :source the source context for parameter resolution
    # @option return [Symbol] :name the method name generated for this parameter
    # @option return [Symbol, Array<Symbol>] :type the parameter type(s) for coercion
    # @option return [Boolean] :required whether the parameter is required for execution
    # @option return [Hash] :options the parameter configuration options
    # @option return [Array<Hash>] :children serialized child parameters for nested structures
    #
    # @example Serialize a nested parameter with children
    #   user_param = Parameter.new(:user, klass: MyTask, type: :hash) do
    #     required :name, type: :string
    #     optional :age, type: :integer
    #   end
    #   ParameterSerializer.call(user_param)
    #   # => {
    #   #   source: :context,
    #   #   name: :user,
    #   #   type: :hash,
    #   #   required: false,
    #   #   options: {},
    #   #   children: [
    #   #     { source: :user, name: :name, type: :string, required: true, options: {}, children: [] },
    #   #     { source: :user, name: :age, type: :integer, required: false, options: {}, children: [] }
    #   #   ]
    #   # }
    def call(parameter)
      {
        source: parameter.method_source,
        name: parameter.method_name,
        type: parameter.type,
        required: parameter.required?,
        options: parameter.options,
        children: parameter.children.map(&:to_h)
      }
    end

  end
end
