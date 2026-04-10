# frozen_string_literal: true

module CMDx
  module Validators
    # Validates the length of a value (string, array, etc.)
    module Length

      # @param value [Object] the value to validate
      # @param is [Integer, nil] exact length
      # @param is_not [Integer, nil] length to reject
      # @param min [Integer, nil] minimum length
      # @param max [Integer, nil] maximum length
      # @param within [Range, nil] length range
      #
      # @return [String, nil] error message or nil
      #
      # @rbs (untyped value, ?is: Integer?, ?is_not: Integer?, ?min: Integer?, ?max: Integer?, ?within: Range[Integer]?, **untyped) -> String?
      def self.call(value, is: nil, is_not: nil, min: nil, max: nil, within: nil, **) # rubocop:disable Metrics/ParameterLists
        return if value.nil?
        return unless value.respond_to?(:length)

        len = value.length

        return Locale.t("cmdx.validators.length.is", is:) if is && len != is

        return Locale.t("cmdx.validators.length.is_not", is_not:) if is_not && len == is_not

        return Locale.t("cmdx.validators.length.min", min:) if min && len < min

        return Locale.t("cmdx.validators.length.max", max:) if max && len > max

        return Locale.t("cmdx.validators.length.within", min: within.min, max: within.max) if within && !within.cover?(len)

        nil
      end

    end
  end
end
