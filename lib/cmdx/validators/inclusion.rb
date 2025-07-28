# frozen_string_literal: true

module CMDx
  module Validators
    module Inclusion

      module_function

      def call(value, options = {})
        values = options[:in] || options[:within]

        if values.is_a?(Range)
          raise_within_validation_error!(values.begin, values.end, options) unless values.cover?(value)
        elsif Array(values).none? { |v| v === value } # rubocop:disable Style/CaseEquality
          raise_of_validation_error!(values, options)
        end
      end

      private

      def raise_of_validation_error!(values, options)
        values  = values.map(&:inspect).join(", ") unless values.nil?
        message = options[:of_message] || options[:message]
        message %= { values: } unless message.nil?

        raise ValidationError, message || I18n.t("cmdx.validators.inclusion.of", values:)
      end

      def raise_within_validation_error!(min, max, options)
        message = options[:in_message] || options[:within_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t("cmdx.validators.inclusion.within", min:, max:)
      end

    end
  end
end
