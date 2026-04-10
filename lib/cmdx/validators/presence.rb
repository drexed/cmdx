# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value is present (not nil, not empty).
    module Presence

      # @param value [Object] the value to validate
      # @param _options [Hash] unused
      #
      # @return [String, nil] error message or nil
      #
      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **)
        return if present?(value)

        Locale.t("cmdx.validators.presence")
      end

      # @rbs (untyped value) -> bool
      def self.present?(value)
        return false if value.nil?
        return false if value.respond_to?(:empty?) && value.empty?

        true
      end

    end
  end
end
