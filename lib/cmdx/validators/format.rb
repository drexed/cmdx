# frozen_string_literal: true

module CMDx
  module Validators
    module Format

      module_function

      def call(value, options = {})
        return if case options[:format]
                  in { with: with, without: without }
                    value.match?(with) && !value.match?(without)
                  in { with: with }
                    value.match?(with)
                  in { without: without }
                    !value.match?(without)
                  end

        raise ValidationError, options.dig(:format, :message) || I18n.t(
          "cmdx.validators.format",
          default: "is an invalid format"
        )
      end

    end
  end
end
