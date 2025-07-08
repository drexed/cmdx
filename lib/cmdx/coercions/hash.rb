# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Hash type.
    #
    # The Hash coercion converts parameter values to Hash objects
    # with support for various input formats including JSON strings,
    # arrays (converted to hash), and Rails parameters.
    #
    # @example Basic hash coercion
    #   class ProcessOrderTask < CMDx::Task
    #     optional :metadata, type: :hash, default: {}
    #     optional :options, type: :hash
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Hash.call({a: 1})              # => {a: 1}
    #   Coercions::Hash.call('{"a":1,"b":2}')     # => {"a"=>1, "b"=>2} (JSON)
    #   Coercions::Hash.call([:a, 1, :b, 2])     # => {:a=>1, :b=>2} (Array)
    #   Coercions::Hash.call("invalid")           # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    class Hash < Coercion

      # Coerce a value to Hash.
      #
      # Supports multiple input formats:
      # - Hash objects (returned as-is)
      # - ActionController::Parameters (returned as-is)
      # - JSON strings starting with '{' (parsed as JSON)
      # - Arrays (converted using Hash[*array])
      #
      # @param value [Object] value to coerce to hash
      # @param _options [Hash] coercion options (unused)
      # @return [Hash] coerced hash value
      # @raise [CoercionError] if coercion fails
      #
      # @example
      #   Coercions::Hash.call({key: "value"})      # => {key: "value"}
      #   Coercions::Hash.call('{"a": 1}')          # => {"a" => 1}
      #   Coercions::Hash.call([:a, 1, :b, 2])     # => {:a => 1, :b => 2}
      def call(value, _options = {})
        case value.class.name
        when "Hash", "ActionController::Parameters"
          value
        when "Array"
          ::Hash[*value]
        when "String"
          value.start_with?("{") ? JSON.parse(value) : raise_coercion_error!
        else
          raise_coercion_error!
        end
      rescue ArgumentError, TypeError, JSON::ParserError
        raise_coercion_error!
      end

      private

      # Raise a standardized coercion error.
      #
      # @return [void]
      # @raise [CoercionError] always raises coercion error
      # @api private
      def raise_coercion_error!
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "hash",
          default: "could not coerce into a hash"
        )
      end

    end
  end
end
