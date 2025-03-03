# frozen_string_literal: true

module CMDx
  module Validators
    module Inclusion

      extend self

      def call(value, options = {})
        values = options.dig(:inclusion, :in) ||
                 options.dig(:inclusion, :within)

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) unless values.cover?(value)
        elsif Array(values).none? { |v| v === value } # rubocop:disable Style/CaseEquality
          raise_of_validation_error!(values, options)
        end
      end

      private

      def raise_of_validation_error!(values, options)
        values  = values.map(&:inspect).join(", ")
        message = options.dig(:inclusion, :of_message) ||
                  options.dig(:inclusion, :message)
        message %= { values: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.inclusion.of",
          values:,
          default: "must be one of: #{values}"
        )
      end

      def raise_within_validation_error!(min, max, options)
        message = options.dig(:inclusion, :in_message) ||
                  options.dig(:inclusion, :within_message) ||
                  options.dig(:inclusion, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.inclusion.within",
          min:,
          max:,
          default: "must be within #{min} and #{max}"
        )
      end

    end
  end
end
