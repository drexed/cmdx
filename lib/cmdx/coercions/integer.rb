# frozen_string_literal: true

module CMDx
  module Coercions
    module Integer

      module_function

      def call(value, options = {}) # rubocop:disable Lint/UnusedMethodArgument
        Integer(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError # rubocop:disable Lint/ShadowedException
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_an",
          type: "integer",
          default: "could not coerce into an integer"
        )
      end

    end
  end
end
