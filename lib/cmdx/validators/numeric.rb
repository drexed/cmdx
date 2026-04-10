# frozen_string_literal: true

module CMDx
  module Validators
    # Validates numeric constraints on a value.
    module Numeric

      # @param value [Object] the value to validate
      # @param is [Numeric, nil] exact value
      # @param is_not [Numeric, nil] rejected value
      # @param min [Numeric, nil] minimum value
      # @param max [Numeric, nil] maximum value
      # @param within [Range, nil] value range
      #
      # @return [String, nil] error message or nil
      #
      # @rbs (untyped value, ?is: Numeric?, ?is_not: Numeric?, ?min: Numeric?, ?max: Numeric?, ?within: Range[Numeric]?, **untyped) -> String?
      def self.call(value, is: nil, is_not: nil, min: nil, max: nil, within: nil, **) # rubocop:disable Metrics/ParameterLists
        return if value.nil?
        return unless value.is_a?(::Numeric)

        return Locale.t("cmdx.validators.numeric.is", is:) if is && value != is

        return Locale.t("cmdx.validators.numeric.is_not", is_not:) if is_not && value == is_not

        return Locale.t("cmdx.validators.numeric.min", min:) if min && value < min

        return Locale.t("cmdx.validators.numeric.max", max:) if max && value > max

        return Locale.t("cmdx.validators.numeric.within", min: within.min, max: within.max) if within && !within.cover?(value)

        nil
      end

    end
  end
end
