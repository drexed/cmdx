# frozen_string_literal: true

module CMDx
  module Validators
    module Length

      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **options)
        config = options[:length]
        return unless config.is_a?(::Hash)

        len = value.respond_to?(:length) ? value.length : value.to_s.length

        return Locale.t("cmdx.validators.length.is", is: config[:is]) if config[:is] && len != config[:is]

        return Locale.t("cmdx.validators.length.is_not", is_not: config[:is_not]) if config[:is_not] && len == config[:is_not]

        return Locale.t("cmdx.validators.length.min", min: config[:min]) if config[:min] && len < config[:min]

        return Locale.t("cmdx.validators.length.max", max: config[:max]) if config[:max] && len > config[:max]

        if config[:within]
          range = config[:within]
          return Locale.t("cmdx.validators.length.within", min: range.min, max: range.max) unless range.include?(len)
        end

        nil
      end

    end
  end
end
