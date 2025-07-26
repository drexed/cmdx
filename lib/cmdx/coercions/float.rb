# frozen_string_literal: true

module CMDx
  module Coercions
    module Float

      module_function

      def call(value, options = {}) # rubocop:disable Lint/UnusedMethodArgument
        Float(value)
      rescue ArgumentError, RangeError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "float",
          default: "could not coerce into a float"
        )
      end

    end
  end
end
