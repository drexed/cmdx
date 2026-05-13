# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to `DateTime`. Pass `strptime:` to parse via a specific format;
    # otherwise `DateTime.parse` is used for strings, and `#to_datetime` for
    # any other responding object.
    module DateTime

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :strptime format string for `DateTime.strptime`
      # @return [DateTime, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        if value.is_a?(::DateTime)
          value
        elsif value.is_a?(::String)
          if (strptime = options[:strptime])
            ::DateTime.strptime(value, strptime)
          else
            ::DateTime.parse(value)
          end
        elsif value.respond_to?(:to_datetime)
          value.to_datetime
        else
          coercion_failure
        end
      rescue ArgumentError, RangeError, TypeError, ::Date::Error
        coercion_failure
      end

      private

      def coercion_failure
        type = I18nProxy.t("cmdx.types.date_time")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end
