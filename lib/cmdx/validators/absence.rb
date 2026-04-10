# frozen_string_literal: true

module CMDx
  module Validators
    module Absence

      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **)
        blank = value.nil? || (value.respond_to?(:empty?) && value.empty?)
        return if blank

        Locale.t("cmdx.validators.absence")
      end

    end
  end
end
