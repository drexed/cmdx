# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to `Date`. Pass `strptime:` to parse via a specific format;
    # otherwise `Date.parse` is used for strings, and `#to_date` for any
    # other responding object.
    module Date

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :strptime format string for `Date.strptime`
      # @return [Date, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        if value.is_a?(::Date)
          value
        elsif value.is_a?(::String)
          if (strptime = options[:strptime])
            ::Date.strptime(value, strptime)
          else
            ::Date.parse(value)
          end
        elsif value.respond_to?(:to_date)
          value.to_date
        else
          coercion_failure
        end
      rescue ArgumentError, TypeError, ::Date::Error
        coercion_failure
      end

      private

      def coercion_failure
        type = I18nProxy.t("cmdx.types.date")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end
