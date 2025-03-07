# frozen_string_literal: true

module CMDx
  module Coercions
    module Date

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      module_function

      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::Date.strptime(value, options[:format]) if options[:format]

        ::Date.parse(value)
      rescue TypeError, ::Date::Error
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "date",
          default: "could not coerce into a date"
        )
      end

    end
  end
end
