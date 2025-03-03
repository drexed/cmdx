# frozen_string_literal: true

module CMDx
  module Coercions
    module Complex

      module_function

      def call(v, _options = {})
        Complex(v)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "complex",
          default: "could not coerce into a complex"
        )
      end

    end
  end
end
