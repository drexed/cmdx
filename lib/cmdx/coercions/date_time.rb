# frozen_string_literal: true

module CMDx
  module Coercions
    module DateTime

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      module_function

      def call(v, options = {})
        return v if ANALOG_TYPES.include?(v.class.name)
        return ::DateTime.strptime(v, options[:format]) if options[:format]

        ::DateTime.parse(v)
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
