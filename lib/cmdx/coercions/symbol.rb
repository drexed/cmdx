# frozen_string_literal: true

module CMDx
  module Coercions
    module Symbol

      extend self

      def call(value, options = {})
        value.to_sym
      rescue NoMethodError
        type = Utils::Locale.translate!("cmdx.types.symbol")
        raise CoercionError, Utils::Locale.translate!("cmdx.coercions.into_a", type:)
      end

    end
  end
end
