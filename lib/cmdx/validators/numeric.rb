# frozen_string_literal: true

module CMDx
  module Validators
    module Numeric

      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **options)
        config = options[:numeric]
        return unless config.is_a?(::Hash)
        return unless value.is_a?(::Numeric)

        return Locale.t("cmdx.validators.numeric.is", is: config[:is]) if config[:is] && value != config[:is]

        return Locale.t("cmdx.validators.numeric.is_not", is_not: config[:is_not]) if config[:is_not] && value == config[:is_not]

        return Locale.t("cmdx.validators.numeric.min", min: config[:min]) if config[:min] && value < config[:min]

        return Locale.t("cmdx.validators.numeric.max", max: config[:max]) if config[:max] && value > config[:max]

        if config[:within]
          range = config[:within]
          return Locale.t("cmdx.validators.numeric.within", min: range.min, max: range.max) unless range.include?(value)
        end

        nil
      end

    end
  end
end
