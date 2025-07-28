# frozen_string_literal: true

module CMDx
  module Validators
    module Format

      module_function

      def call(value, options = {})
        match =
          case options
          in { with: with, without: without }
            value.match?(with) && !value.match?(without)
          in { with: with }
            value.match?(with)
          in { without: without }
            !value.match?(without)
          else
            false
          end

        return if match

        raise ValidationError, options[:message] || I18n.t("cmdx.validators.format")
      end

    end
  end
end
