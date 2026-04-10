# frozen_string_literal: true

module CMDx
  module Validators
    # Validates that a value matches a given regular expression.
    module Format

      # @param value [Object] the value to validate
      # @param with [Regexp] the pattern to match
      #
      # @return [String, nil] error message or nil
      #
      # @rbs (untyped value, ?with: Regexp?, **untyped) -> String?
      def self.call(value, with: nil, **)
        return if value.nil?
        return unless with
        return if with.match?(value.to_s)

        Locale.t("cmdx.validators.format")
      end

    end
  end
end
