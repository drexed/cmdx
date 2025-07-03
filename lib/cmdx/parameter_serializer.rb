# frozen_string_literal: true

module CMDx
  # Parameter serialization utility for converting Parameter objects to hash representations.
  #
  # The ParameterSerializer module provides functionality to serialize Parameter
  # instances into structured hash representations suitable for inspection,
  # logging, debugging, and data interchange.
  #
  # @example Basic parameter serialization
  #   parameter = Parameter.new(:user_id, klass: Task, type: :integer, required: true)
  #   ParameterSerializer.call(parameter)
  #   # => {
  #   #   source: :context,
  #   #   name: :user_id,
  #   #   type: :integer,
  #   #   required: true,
  #   #   options: {},
  #   #   children: []
  #   # }
  #
  # @example Parameter with validation options
  #   parameter = Parameter.new(:email, klass: Task, type: :string,
  #                           format: { with: /@/ }, presence: true)
  #   ParameterSerializer.call(parameter)
  #   # => {
  #   #   source: :context,
  #   #   name: :email,
  #   #   type: :string,
  #   #   required: false,
  #   #   options: { format: { with: /@/ }, presence: true },
  #   #   children: []
  #   # }
  #
  # @example Nested parameter serialization
  #   parent = Parameter.new(:address, klass: Task) do
  #     required :street, :city
  #   end
  #   ParameterSerializer.call(parent)
  #   # => {
  #   #   source: :context,
  #   #   name: :address,
  #   #   type: :virtual,
  #   #   required: false,
  #   #   options: {},
  #   #   children: [
  #   #     { source: :address, name: :street, type: :virtual, required: true, options: {}, children: [] },
  #   #     { source: :address, name: :city, type: :virtual, required: true, options: {}, children: [] }
  #   #   ]
  #   # }
  #
  # @see CMDx::Parameter Parameter object creation and configuration
  # @see CMDx::ParameterInspector Human-readable parameter formatting
  module ParameterSerializer

    module_function

    # Converts a Parameter object to a hash representation.
    #
    # Serializes a Parameter instance into a structured hash containing
    # all relevant parameter information including source, name, type,
    # requirement status, options, and recursively serialized children.
    #
    # @param parameter [CMDx::Parameter] The parameter object to serialize
    # @return [Hash] Structured hash representation of the parameter
    #
    # @example Simple parameter serialization
    #   param = Parameter.new(:age, klass: Task, type: :integer, required: true)
    #   ParameterSerializer.call(param)
    #   # => {
    #   #   source: :context,
    #   #   name: :age,
    #   #   type: :integer,
    #   #   required: true,
    #   #   options: {},
    #   #   children: []
    #   # }
    #
    # @example Parameter with custom source and options
    #   param = Parameter.new(:name, klass: Task, source: :user,
    #                        type: :string, length: { min: 2 })
    #   ParameterSerializer.call(param)
    #   # => {
    #   #   source: :user,
    #   #   name: :name,
    #   #   type: :string,
    #   #   required: false,
    #   #   options: { length: { min: 2 } },
    #   #   children: []
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
