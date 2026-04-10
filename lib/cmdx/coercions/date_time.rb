# frozen_string_literal: true

require "date"

module CMDx
  module Coercions
    # Coerces a value into a DateTime.
    module DateTime

      # @param value [Object]
      # @return [DateTime]
      #
      # @rbs (untyped value) -> DateTime
      def self.call(value)
        case value
        when ::DateTime then value
        when ::Date, ::Time then value.to_datetime
        when ::String then ::DateTime.parse(value)
        when ::Integer, ::Float then ::Time.at(value).to_datetime
        else ::DateTime.parse(value.to_s)
        end
      rescue StandardError
        raise Error, Locale.t("cmdx.coercions.into_a", type: "date time")
      end

    end
  end
end
