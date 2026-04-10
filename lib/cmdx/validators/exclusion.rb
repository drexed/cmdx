# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is NOT within a given set or range.
    module Exclusion

      # @param value [Object] the value to validate
      # @param of [Array, nil] excluded values
      # @param within [Range, nil] excluded range
      #
      # @return [String, nil] error message or nil
      #
      # @rbs (untyped value, ?of: Array[untyped]?, ?within: Range[untyped]?, **untyped) -> String?
      def self.call(value, of: nil, within: nil, **)
        return if value.nil?

        if of
          return unless of.include?(value)

          Locale.t("cmdx.validators.exclusion.of", values: of.join(", "))
        elsif within
          return unless within.cover?(value)

          Locale.t("cmdx.validators.exclusion.within", min: within.min, max: within.max)
        end
      end

    end
  end
end
