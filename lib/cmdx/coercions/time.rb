# frozen_string_literal: true

module CMDx
  class Coercions
    # Coerces to `Time`. Strings use `Time.parse` (or `strptime` when
    # supplied); Numerics are treated as epoch seconds; objects responding
    # to `#to_time` are unwrapped.
    module Time

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :strptime format string for `Time.strptime`
      # @return [Time, Coercions::Failure]
      def call(value, options = EMPTY_HASH)
        if value.is_a?(::Time)
          value
        elsif value.is_a?(::String)
          if (strptime = options[:strptime])
            ::Time.strptime(value, strptime)
          else
            ::Time.parse(value)
          end
        elsif value.is_a?(::Numeric)
          ::Time.at(value)
        elsif value.respond_to?(:to_time)
          value.to_time
        else
          coercion_failure
        end
      rescue ArgumentError, TypeError
        coercion_failure
      end

      private

      def coercion_failure
        type = I18nProxy.t("cmdx.types.time")
        Failure.new(I18nProxy.t("cmdx.coercions.into_a", type:))
      end

    end
  end
end
