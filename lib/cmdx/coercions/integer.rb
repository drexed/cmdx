# frozen_string_literal: true

module CMDx
  module Coercions
    module Integer

      module_function

      def call(value, _options = {})
        Integer(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_an",
          type: "integer",
          default: "could not coerce into an integer"
        )
      end

    end
  end
end
