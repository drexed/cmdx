# frozen_string_literal: true

module CMDx
  module Coercions
    module DateTime

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      module_function

      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::DateTime.strptime(value, options[:strptime]) if options[:strptime]

        ::DateTime.parse(value)
      rescue TypeError, ::Date::Error
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "datetime",
          default: "could not coerce into a datetime"
        )
      end

    end
  end
end
