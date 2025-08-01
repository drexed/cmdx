# frozen_string_literal: true

module CMDx
  module Coercions
    module Integer

      extend self

      def call(value, options = {})
        Integer(value)
      rescue ArgumentError, FloatDomainError, RangeError, TypeError # rubocop:disable Lint/ShadowedException
        type = Utils::Locale.translate!("cmdx.types.integer")
        raise CoercionError, Utils::Locale.translate!("cmdx.coercions.into_an", type:)
      end

    end
  end
end
