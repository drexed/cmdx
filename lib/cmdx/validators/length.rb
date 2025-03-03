# frozen_string_literal: true

module CMDx
  module Validators
    module Length

      extend self

      def call(value, options = {})
        case options[:length]
        in { within: within }
          raise_within_validation_error!(within.begin, within.end, options) unless within.cover?(value.length)
        in { not_within: not_within }
          raise_not_within_validation_error!(not_within.begin, not_within.end, options) if not_within.cover?(value.length)
        in { in: yn }
          raise_within_validation_error!(yn.begin, yn.end, options) unless yn.cover?(value.length)
        in { not_in: not_in }
          raise_not_within_validation_error!(not_in.begin, not_in.end, options) if not_in.cover?(value.length)
        in { min: min, max: max }
          raise_within_validation_error!(min, max, options) unless value.length.between?(min, max)
        in { min: min }
          raise_min_validation_error!(min, options) unless min <= value.length
        in { max: max }
          raise_max_validation_error!(max, options) unless value.length <= max
        in { is: is }
          raise_is_validation_error!(is, options) unless value.length == is
        in { is_not: is_not }
          raise_is_not_validation_error!(is_not, options) if value.length == is_not
        else
          raise ArgumentError, "no known length validator options given"
        end
      end

      private

      def raise_within_validation_error!(min, max, options)
        message = options.dig(:length, :within_message) ||
                  options.dig(:length, :in_message) ||
                  options.dig(:length, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.within",
          min:,
          max:,
          default: "length must be within #{min} and #{max}"
        )
      end

      def raise_not_within_validation_error!(min, max, options)
        message = options.dig(:length, :not_within_message) ||
                  options.dig(:length, :not_in_message) ||
                  options.dig(:length, :message)
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.not_within",
          min:,
          max:,
          default: "length must not be within #{min} and #{max}"
        )
      end

      def raise_min_validation_error!(min, options)
        message = options.dig(:length, :min_message) ||
                  options.dig(:length, :message)
        message %= { min: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.min",
          min:,
          default: "length must be at least #{min}"
        )
      end

      def raise_max_validation_error!(max, options)
        message = options.dig(:length, :max_message) ||
                  options.dig(:length, :message)
        message %= { max: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.max",
          max:,
          default: "length must be at most #{max}"
        )
      end

      def raise_is_validation_error!(is, options)
        message = options.dig(:length, :is_message) ||
                  options.dig(:length, :message)
        message %= { is: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.is",
          is:,
          default: "length must be #{is}"
        )
      end

      def raise_is_not_validation_error!(is_not, options)
        message = options.dig(:length, :is_not_message) ||
                  options.dig(:length, :message)
        message %= { is_not: } unless message.nil?

        raise ValidationError, message || I18n.t(
          "cmdx.validators.length.is_not",
          is_not:,
          default: "length must not be #{is_not}"
        )
      end

    end
  end
end
