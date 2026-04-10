# frozen_string_literal: true

require "date"

module CMDx
  module Coercions
    # Coerces a value into a Date.
    module Date

      # @param value [Object]
      # @return [Date]
      #
      # @rbs (untyped value) -> Date
      def self.call(value)
        case value
        when ::Date then value
        when ::Time, ::DateTime then value.to_date
        when ::String then ::Date.parse(value)
        when ::Integer, ::Float then ::Time.at(value).to_date
        else ::Date.parse(value.to_s)
        end
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "date")
      end

    end
  end
end
