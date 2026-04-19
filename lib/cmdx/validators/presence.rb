# frozen_string_literal: true

module CMDx
  class Validators
    # Validates that a value is present: non-`nil`, non-empty, and (for
    # strings) not whitespace-only.
    module Presence

      extend self

      # @param value [Object]
      # @param options [Hash{Symbol => Object}]
      # @option options [String] :message override for the failure message
      # @return [Validators::Failure, nil]
      def call(value, options = EMPTY_HASH)
        present =
          if value.is_a?(String)
            /\S/.match?(value)
          elsif value.respond_to?(:empty?)
            !value.empty?
          else
            !value.nil?
          end

        return if present

        Failure.new(options[:message] || I18nProxy.t("cmdx.validators.presence"))
      end

    end
  end
end
