# frozen_string_literal: true

module CMDx
  module Validators
    module Format

      extend self

      def call(value, options = {})
        match =
          case options
          in with:, without:
            value.match?(with) && !value.match?(without)
          in with:
            value.match?(with)
          in without:
            !value.match?(without)
          else
            false
          end

        return if match

        raise ValidationError, options[:message] || Utils::Locale.translate!("cmdx.validators.format")
      end

    end
  end
end
