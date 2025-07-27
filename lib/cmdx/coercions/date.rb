# frozen_string_literal: true

module CMDx
  module Coercions
    module Date

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      module_function

      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::Date.strptime(value, options[:strptime]) if options[:strptime]

        ::Date.parse(value)
      rescue TypeError, ::Date::Error
        type = Utils::Locale.t("cmdx.types.date")
        raise CoercionError, Utils::Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end
