# frozen_string_literal: true

module CMDx
  class Validators
    # Validates that a value is blank: `nil`, whitespace-only string, or
    # empty collection.
    module Absence

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

        return unless present

        Failure.new(options[:message] || I18nProxy.t("cmdx.validators.absence"))
      end

    end
  end
end
