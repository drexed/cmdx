# frozen_string_literal: true

require "time"

module CMDx
  module Coercions
    # Coerces a value into a Time.
    module Time

      # @param value [Object]
      # @return [Time]
      #
      # @rbs (untyped value) -> Time
      def self.call(value)
        case value
        when ::Time then value
        when ::Date, ::DateTime then value.to_time
        when ::String then ::Time.parse(value)
        when ::Integer, ::Float then ::Time.at(value)
        else ::Time.parse(value.to_s)
        end
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "time")
      end

    end
  end
end
