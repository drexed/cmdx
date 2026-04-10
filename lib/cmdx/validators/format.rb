# frozen_string_literal: true

module CMDx
  module Validators
    module Format

      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **options)
        pattern = options[:format]
        return unless pattern.is_a?(Regexp)
        return if value.to_s.match?(pattern)

        Locale.t("cmdx.validators.format")
      end

    end
  end
end
