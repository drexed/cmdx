# frozen_string_literal: true

module CMDx
  module Validators
    module Length

      extend self

      def call(value, options = {})
        case options
        in within:
          raise_within_validation_error!(within.begin, within.end, options) unless within.cover?(value.length)
        in not_within:
          raise_not_within_validation_error!(not_within.begin, not_within.end, options) if not_within.cover?(value.length)
        in in: xin
          raise_within_validation_error!(xin.begin, xin.end, options) unless xin.cover?(value.length)
        in not_in:
          raise_not_within_validation_error!(not_in.begin, not_in.end, options) if not_in.cover?(value.length)
        in min:, max:
          raise_within_validation_error!(min, max, options) unless value.length.between?(min, max)
        in min:
          raise_min_validation_error!(min, options) unless min <= value.length
        in max:
          raise_max_validation_error!(max, options) unless value.length <= max
        in is:
          raise_is_validation_error!(is, options) unless value.length == is
        in is_not:
          raise_is_not_validation_error!(is_not, options) if value.length == is_not
        else
          raise ArgumentError, "unknown length validator options given"
        end
      end

      private

      def raise_within_validation_error!(min, max, options)
        message = options[:within_message] || options[:in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Utils::Locale.t("cmdx.validators.length.within", min:, max:)
      end

      def raise_not_within_validation_error!(min, max, options)
        message = options[:not_within_message] || options[:not_in_message] || options[:message]
        message %= { min:, max: } unless message.nil?

        raise ValidationError, message || Utils::Locale.t("cmdx.validators.length.not_within", min:, max:)
      end

      def raise_min_validation_error!(min, options)
        message = options[:min_message] || options[:message]
        message %= { min: } unless message.nil?

        raise ValidationError, message || Utils::Locale.t("cmdx.validators.length.min", min:)
      end

      def raise_max_validation_error!(max, options)
        message = options[:max_message] || options[:message]
        message %= { max: } unless message.nil?

        raise ValidationError, message || Utils::Locale.t("cmdx.validators.length.max", max:)
      end

      def raise_is_validation_error!(is, options)
        message = options[:is_message] || options[:message]
        message %= { is: } unless message.nil?

        raise ValidationError, message || Utils::Locale.t("cmdx.validators.length.is", is:)
      end

      def raise_is_not_validation_error!(is_not, options)
        message = options[:is_not_message] || options[:message]
        message %= { is_not: } unless message.nil?

        raise ValidationError, message || Utils::Locale.t("cmdx.validators.length.is_not", is_not:)
      end

    end
  end
end
