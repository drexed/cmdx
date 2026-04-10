# frozen_string_literal: true

module CMDx
  # Resolves translatable messages. Delegates to I18n when available,
  # falls back to a bundled YAML file.
  module Locale

    LOCALE_PATH = File.expand_path("../locales/en.yml", __dir__).freeze

    # @param key [String] dot-separated key (e.g. "cmdx.faults.invalid")
    # @param options [Hash] interpolation values
    # @return [String]
    #
    # @rbs (String key, **untyped options) -> String
    def self.t(key, **options)
      if defined?(I18n)
        I18n.t(key, **options, default: yaml_lookup(key, **options))
      else
        yaml_lookup(key, **options)
      end
    end

    # @rbs (String key, **untyped options) -> String
    def self.yaml_lookup(key, **options)
      value = key.delete_prefix("en.").split(".").reduce(translations) { |h, k| h.is_a?(Hash) ? h[k] : h }
      return key unless value.is_a?(String)

      options.each { |k, v| value = value.gsub("%{#{k}}", v.to_s) }
      value
    end

    # @rbs () -> Hash[String, untyped]
    def self.translations
      @translations ||= YAML.safe_load_file(LOCALE_PATH)&.dig("en") || {}
    end

    # @rbs () -> void
    def self.reset!
      @translations = nil
    end

  end
end
