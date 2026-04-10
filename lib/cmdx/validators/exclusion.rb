# frozen_string_literal: true

module CMDx
  module Validators
    module Exclusion

      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **options)
        config = options[:exclusion]
        return unless config

        case config
        when ::Hash
          if config[:in] || config[:of]
            list = config[:in] || config[:of]
            return unless list.include?(value)

            Locale.t("cmdx.validators.exclusion.of", values: list.join(", "))
          elsif config[:within] || (config[:min] && config[:max])
            min = config[:min] || config[:within]&.min
            max = config[:max] || config[:within]&.max
            return unless value.respond_to?(:between?) && value.between?(min, max)

            Locale.t("cmdx.validators.exclusion.within", min:, max:)
          end
        when ::Array
          return unless config.include?(value)

          Locale.t("cmdx.validators.exclusion.of", values: config.join(", "))
        when ::Range
          return unless config.include?(value)

          Locale.t("cmdx.validators.exclusion.within", min: config.min, max: config.max)
        end
      end

    end
  end
end
