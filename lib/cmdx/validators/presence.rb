# frozen_string_literal: true

module CMDx
  module Validators
    module Presence

      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **)
        return if value.respond_to?(:empty?) ? !value.empty? : !value.nil?

        Locale.t("cmdx.validators.presence")
      end

    end
  end
end
