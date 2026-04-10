# frozen_string_literal: true

module CMDx
  module Validators
    module Inclusion

      # @rbs (untyped value, **untyped) -> String?
      def self.call(value, **options)
        config = options[:inclusion]
        return unless config

        case config
        when ::Hash
          if config[:in] || config[:of]
            list = config[:in] || config[:of]
            return if list.include?(value)

            Locale.t("cmdx.validators.inclusion.of", values: list.join(", "))
          elsif config[:within] || (config[:min] && config[:max])
            min = config[:min] || config[:within]&.min
            max = config[:max] || config[:within]&.max
            return if value.respond_to?(:between?) && value.between?(min, max)

            Locale.t("cmdx.validators.inclusion.within", min:, max:)
          end
        when ::Array
          return if config.include?(value)

          Locale.t("cmdx.validators.inclusion.of", values: config.join(", "))
        when ::Range
          return if config.include?(value)

          Locale.t("cmdx.validators.inclusion.within", min: config.min, max: config.max)
        end
      end

    end
  end
end
