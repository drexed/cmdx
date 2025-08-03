# frozen_string_literal: true

module CMDx
  module Coercions
    module Time

      extend self

      ANALOG_TYPES = %w[DateTime Time].freeze

      def call(value, options = {})
        return value if ANALOG_TYPES.include?(value.class.name)
        return value.to_time if value.respond_to?(:to_time)
        return ::Time.strptime(value, options[:strptime]) if options[:strptime]

        ::Time.parse(value)
      rescue ArgumentError, TypeError
        type = Locale.t("cmdx.types.time")
        raise CoercionError, Locale.t("cmdx.coercions.into_a", type:)
      end

    end
  end
end
