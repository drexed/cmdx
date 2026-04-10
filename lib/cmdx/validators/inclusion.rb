# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is within a given set or range.
    module Inclusion

      # @param value [Object] the value to validate
      # @param of [Array, nil] allowed values
      # @param within [Range, nil] allowed range
      #
      # @return [String, nil] error message or nil
      #
      # @rbs (untyped value, ?of: Array[untyped]?, ?within: Range[untyped]?, **untyped) -> String?
      def self.call(value, of: nil, within: nil, **)
        return if value.nil?

        if of
          return if of.include?(value)

          Locale.t("cmdx.validators.inclusion.of", values: of.join(", "))
        elsif within
          return if within.cover?(value)

          Locale.t("cmdx.validators.inclusion.within", min: within.min, max: within.max)
        end
      end

    end
  end
end
