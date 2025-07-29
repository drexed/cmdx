# frozen_string_literal: true

module CMDx
  module Coercions
    module Integer

      extend self

      def call(value, options = {})
        Integer(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError # rubocop:disable Lint/ShadowedException
        type = Locale.t("cmdx.types.integer")
        raise CoercionError, Locale.t("cmdx.coercions.into_an", type:)
      end

    end
  end
end
