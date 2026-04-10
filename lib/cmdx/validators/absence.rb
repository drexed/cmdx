# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is absent (nil or empty).
    module Absence

      # @param value [Object] the value to validate
      # @param _options [Hash] unused
      #
      # @return [String, nil] error message or nil
      #
      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **)
        return if value.nil?
        return if value.respond_to?(:empty?) && value.empty?

        Locale.t("cmdx.validators.absence")
      end

    end
  end
end
