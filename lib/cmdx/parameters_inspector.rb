# frozen_string_literal: true

module CMDx
  # Parameter collection inspection utility for generating human-readable descriptions.
  #
  # The ParametersInspector module provides functionality to convert collections
  # of parameters into formatted, human-readable string representations. It
  # coordinates with ParameterInspector to format individual parameters and
  # combines them into a cohesive multi-parameter description.
  #
  # @example Basic parameters collection inspection
  #   parameter_registry = ParameterRegistry.new
  #   parameter_registry << Parameter.new(:user_id, klass: Task, type: :integer, required: true)
  #   parameter_registry << Parameter.new(:email, klass: Task, type: :string, required: false)
  #
  #   ParametersInspector.call(parameter_registry)
  #   # => "Parameter: name=user_id type=integer source=context required=true options={}
  #   #     Parameter: name=email type=string source=context required=false options={}"
  #
  # @example Empty parameters collection
  #   empty_parameter_registry = ParameterRegistry.new
  #   ParametersInspector.call(empty_parameter_registry)
  #   # => ""
  #
  # @example Parameters with validation options
  #   parameter_registry = ParameterRegistry.new
  #   parameter_registry << Parameter.new(:age, klass: Task, type: :integer,
  #                              numeric: { within: 18..120 }, required: true)
  #   parameter_registry << Parameter.new(:website, klass: Task, type: :string,
  #                              format: { with: /^https?:\/\// }, required: false)
  #
  #   ParametersInspector.call(parameter_registry)
  #   # => "Parameter: name=age type=integer source=context required=true options={numeric: {within: 18..120}}
  #   #     Parameter: name=website type=string source=context required=false options={format: {with: /^https?:\/\//}}"
  #
  # @see CMDx::ParameterRegistry Parameter collection management
  # @see CMDx::ParameterInspector Individual parameter inspection
  # @see CMDx::Parameter Parameter definition and configuration
  module ParametersInspector

    module_function

    # Converts a Parameters collection to a human-readable string representation.
    #
    # Iterates through all parameters in the collection and formats each one
    # using ParameterInspector, then joins them with newlines to create a
    # comprehensive multi-parameter description.
    #
    # @param parameters [CMDx::ParameterRegistry] The parameters collection to inspect
    # @return [String] Multi-line formatted parameter descriptions
    #
    # @example Inspecting multiple parameters
    #   ParametersInspector.call(parameters_collection)
    #   # => "Parameter: name=user_id type=integer source=context required=true
    #   #     Parameter: name=email type=string source=context required=false
    #   #     Parameter: name=age type=integer source=context required=true"
    #
    # @example Inspecting empty collection
    #   ParametersInspector.call(ParameterRegistry.new)
    #   # => ""
    #
    # @example Inspecting single parameter collection
    #   single_param_collection = ParameterRegistry.new
    #   single_param_collection << Parameter.new(:name, klass: Task)
    #   ParametersInspector.call(single_param_collection)
    #   # => "Parameter: name=name type=virtual source=context required=false options={}"
    def call(parameters)
      parameters.registry.map(&:to_s).join("\n")
    end

  end
end
