# frozen_string_literal: true

module CMDx
  module Validators
    module Presence

      extend self

      def call(value, options = {})
        match =
          if value.is_a?(String)
            /\S/.match?(value)
          elsif value.respond_to?(:empty?)
            !value.empty?
          else
            !value.nil?
          end

        return if match

        message = options[:message] if options.is_a?(Hash)
        raise ValidationError, message || Locale.translate!("cmdx.validators.presence")
      end

    end
  end
end
