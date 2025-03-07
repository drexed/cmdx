# frozen_string_literal: true

module CMDx
  module Coercions
    module Time

      ANALOG_TYPES = %w[Date DateTime Time].freeze

      module_function

      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return ::Time.strptime(value, options[:format]) if options[:format]

        ::Time.parse(value)
      rescue ArgumentError, TypeError
        raise CoercionError, I18n.t(
          "cmdx.coercions.into_a",
          type: "time",
          default: "could not coerce into a time"
        )
      end

    end
  end
end
