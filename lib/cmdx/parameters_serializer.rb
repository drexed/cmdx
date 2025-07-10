# frozen_string_literal: true

module CMDx
  # Parameter collection serialization utility for converting Parameters to hash arrays.
  #
  # The ParametersSerializer module provides functionality to serialize collections
  # of Parameter instances into structured array representations. Each parameter
  # in the collection is converted to its hash representation, creating a
  # comprehensive data structure suitable for inspection, logging, and data interchange.
  #
  # @example Basic parameters collection serialization
  #   parameter_registry = ParameterRegistry.new
  #   parameter_registry << Parameter.new(:user_id, klass: Task, type: :integer, required: true)
  #   parameters << Parameter.new(:email, klass: Task, type: :string, required: false)
  #
  #   ParametersSerializer.call(parameters)
  #   # => [
  #   #   {
  #   #     source: :context,
  #   #     name: :user_id,
  #   #     type: :integer,
  #   #     required: true,
  #   #     options: {},
  #   #     children: []
  #   #   },
  #   #   {
  #   #     source: :context,
  #   #     name: :email,
  #   #     type: :string,
  #   #     required: false,
  #   #     options: {},
  #   #     children: []
  #   #   }
  #   # ]
  #
  # @example Empty parameters collection
  #   empty_parameter_registry = ParameterRegistry.new
  #   ParametersSerializer.call(empty_parameter_registry)
  #   # => []
  #
  # @example Parameters with validation and nested structures
  #   parameter_registry = ParameterRegistry.new
  #   parameter_registry << Parameter.new(:age, klass: Task, type: :integer,
  #                              numeric: { within: 18..120 }, required: true)
  #
  #   address_param = Parameter.new(:address, klass: Task) do
  #     required :street, :city
  #     optional :apartment
  #   end
  #   parameter_registry << address_param
  #
  #   ParametersSerializer.call(parameter_registry)
  #   # => [
  #   #   {
  #   #     source: :context,
  #   #     name: :age,
  #   #     type: :integer,
  #   #     required: true,
  #   #     options: { numeric: { within: 18..120 } },
  #   #     children: []
  #   #   },
  #   #   {
  #   #     source: :context,
  #   #     name: :address,
  #   #     type: :virtual,
  #   #     required: false,
  #   #     options: {},
  #   #     children: [
  #   #       { source: :address, name: :street, type: :virtual, required: true, options: {}, children: [] },
  #   #       { source: :address, name: :city, type: :virtual, required: true, options: {}, children: [] },
  #   #       { source: :address, name: :apartment, type: :virtual, required: false, options: {}, children: [] }
  #   #     ]
  #   #   }
  #   # ]
  #
  # @see CMDx::ParameterRegistry Parameter collection management
  # @see CMDx::ParameterSerializer Individual parameter serialization
  # @see CMDx::Parameter Parameter definition and configuration
  module ParametersSerializer

    module_function

    # Converts a Parameters collection to an array of hash representations.
    #
    # Iterates through all parameters in the collection and converts each one
    # to its hash representation using the Parameter#to_h method, which delegates
    # to ParameterSerializer.
    #
    # @param parameters [CMDx::ParameterRegistry] The parameters collection to serialize
    # @return [Array<Hash>] Array of serialized parameter data structures
    #
    # @example Serializing multiple parameters
    #   ParametersSerializer.call(parameters_collection)
    #   # => [
    #   #   { source: :context, name: :user_id, type: :integer, required: true, options: {}, children: [] },
    #   #   { source: :context, name: :email, type: :string, required: false, options: {}, children: [] }
    #   # ]
    #
    # @example Serializing empty collection
    #   ParametersSerializer.call(ParameterRegistry.new)
    #   # => []
    #
    # @example Serializing single parameter collection
    #   single_param_collection = ParameterRegistry.new
    #   single_param_collection << Parameter.new(:name, klass: Task, type: :string)
    #   ParametersSerializer.call(single_param_collection)
    #   # => [
    #   #   { source: :context, name: :name, type: :string, required: false, options: {}, children: [] }
    #   # ]
    def call(parameters)
      parameters.registry.map(&:to_h)
    end

  end
end
