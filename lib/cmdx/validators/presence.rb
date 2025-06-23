# frozen_string_literal: true

module CMDx
  module Validators
    module Presence

      module_function

      def call(value, options = {})
        present =
          if value.is_a?(String)
            /\S/.match?(value)
          elsif value.respond_to?(:empty?)
            !value.empty?
          else
            !value.nil?
          end

        return if present

        message = options.dig(:presence, :message) if options[:presence].is_a?(Hash)
        raise ValidationError, message || I18n.t(
          "cmdx.validators.presence",
          default: "cannot be empty"
        )
      end

    end
  end
end
