# frozen_string_literal: true

module CMDx
  module Validators
    module Exclusion

      extend self

      def call(value, options = {})
        values = options.dig(:exclusion, :in) ||
                 options.dig(:exclusion, :within)

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) if values.cover?(value)
        elsif Array(values).any? { |v| v === value } # rubocop:disable Style/CaseEquality
          raise_of_validation_error!(values, options)
        end
      end

      private

      def raise_of_validation_error!(values, options)
        values  = values.map(&:inspect).join(", ")
        message = options.dig(:exclusion, :of_message) ||
                  options.dig(:exclusion, :message)
        message %= { values: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.exclusion.of",
          values:,
          default: "must not be one of: #{values}"
        )
      end

      def raise_within_validation_error!(min, max, options)
        message = options.dig(:exclusion, :in_message) ||
                  options.dig(:exclusion, :within_message) ||
                  options.dig(:exclusion, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.exclusion.within",
          min:,
          max:,
          default: "must not be within #{min} and #{max}"
        )
      end

    end
  end
end
