# frozen_string_literal: true

module CMDx
  module Coercions
    # Coerces values to Boolean type (true/false).
    #
    # The Boolean coercion converts parameter values to true or false
    # based on string pattern matching for common boolean representations.
    # It handles various textual representations of true and false values.
    #
    # @example Basic boolean coercion
    #   class ProcessOrderTask < CMDx::Task
    #     optional :send_email, type: :boolean, default: true
    #     optional :is_urgent, type: :boolean, default: false
    #   end
    #
    # @example Coercion behavior
    #   Coercions::Boolean.call("true")     # => true
    #   Coercions::Boolean.call("yes")      # => true
    #   Coercions::Boolean.call("1")        # => true
    #   Coercions::Boolean.call("false")    # => false
    #   Coercions::Boolean.call("no")       # => false
    #   Coercions::Boolean.call("0")        # => false
    #   Coercions::Boolean.call("invalid")  # => raises CoercionError
    #
    # @see ParameterValue Parameter value coercion
    # @see Parameter Parameter type definitions
    module Boolean

      # Pattern matching false-like values (case insensitive)
      # @return [Regexp] regex for falsey string values
      FALSEY = /^(false|f|no|n|0)$/i

      # Pattern matching true-like values (case insensitive)
      # @return [Regexp] regex for truthy string values
      TRUTHY = /^(true|t|yes|y|1)$/i

      module_function

      # Coerce a value to Boolean.
      #
      # @param value [Object] value to coerce to boolean
      # @param _options [Hash] coercion options (unused)
      # @return [Boolean] coerced boolean value (true or false)
      # @raise [CoercionError] if value cannot be coerced to boolean
      #
      # @example
      #   Coercions::Boolean.call("yes")    # => true
      #   Coercions::Boolean.call("False")  # => false
      #   Coercions::Boolean.call("1")      # => true
      #   Coercions::Boolean.call("0")      # => false
      def call(value, _options = {})
        case value.to_s.downcase
        when FALSEY then false
        when TRUTHY then true
        else
          raise CoercionError, I18n.t(
            "cmdx.coercions.into_a",
            type: "boolean",
            default: "could not coerce into a boolean"
          )
        end
      end

    end
  end
end
