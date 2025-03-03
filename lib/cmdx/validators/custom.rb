# frozen_string_literal: true

module CMDx
  module Validators
    module Custom

      module_function

      def call(value, options = {})
        return if options.dig(:custom, :validator).call(value, options)

        raise ValidationError, options.dig(:custom, :message) || I18n.t(
          "cmdx.validators.custom",
          default: "is not valid"
        )
      end

    end
  end
end
