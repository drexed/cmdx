# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Array type.
    #
    # The Array coercion converts parameter values to Array objects,
    # with special handling for JSON-formatted strings and general
    # array conversion using Ruby's Array() method.
    #
    # @example Basic array coercion
    #   class ProcessOrderTask < CMDx::Task
    #     optional :tags, type: :array, default: []
    #     optional :item_ids, type: :array
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Array.call([1, 2, 3])      # => [1, 2, 3]
    #   Coercions::Array.call("hello")        # => ["hello"]
    #   Coercions::Array.call('["a","b"]')    # => ["a", "b"] (JSON)
    #   Coercions::Array.call('[1,2,3]')      # => [1, 2, 3] (JSON)
    #   Coercions::Array.call(nil)            # => []
    #   Coercions::Array.call(42)             # => [42]
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    module Array

      module_function

      # Coerce a value to Array.
      #
      # If the value is a JSON-formatted string (starts with '['), it will
      # be parsed as JSON. Otherwise, it uses Ruby's Array() method for
      # general array conversion.
      #
      # @param value [Object] value to coerce to array
      # @param _options [Hash] coercion options (unused)
      # @return [Array] coerced array value
      # @raise [JSON::ParserError] if JSON parsing fails
      #
      # @example
      #   Coercions::Array.call("test")         # => ["test"]
      #   Coercions::Array.call('["a","b"]')    # => ["a", "b"]
      #   Coercions::Array.call([1, 2])         # => [1, 2]
      def call(value, _options = {})
        if value.is_a?(::String) && value.start_with?("[")
          JSON.parse(value)
        else
          Array(value)
        end
      end

    end
  end
end
