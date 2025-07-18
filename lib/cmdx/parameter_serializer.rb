# frozen_string_literal: true

module CMDx
  # Parameter serialization module for converting parameter objects to hash format.
  #
  # This module provides functionality to serialize parameter objects into a
  # standardized hash representation that includes essential metadata about
  # the parameter such as its source, name, type, required status, options,
  # and child parameters. The serialized format is commonly used for debugging,
  # logging, and introspection purposes.
  module ParameterSerializer

    module_function

    # Serializes a parameter object into a hash representation.
    #
    # @param parameter [Parameter] the parameter object to serialize
    #
    # @return [Hash] a hash containing the parameter's metadata
    #
    # @raise [NoMethodError] if the parameter doesn't respond to required methods
    #
    # @example Serialize a parameter with nested children
    #   param = Parameter.new(:user, klass: MyTask, type: :hash) do
    #     required :name, type: :string
    #     optional :age, type: :integer
    #   end
    #   ParameterSerializer.call(param)
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
