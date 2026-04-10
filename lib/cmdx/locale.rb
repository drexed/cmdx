# frozen_string_literal: true

require "yaml"

module CMDx
  # Handles internationalization of messages and error strings.
  # Uses I18n when available, falls back to built-in YAML translations.
  module Locale

    # @rbs LOCALE_PATH: String
    LOCALE_PATH = File.expand_path("../locales", __dir__)

    # @rbs @translations: Hash[String, untyped]

    # Translates a key with optional interpolation.
    #
    # @param key [String] dot-separated translation key (e.g., "cmdx.errors.blank")
    # @param options [Hash] interpolation values
    #
    # @return [String] translated string
    #
    # @rbs (String key, **untyped options) -> String
    def self.t(key, **options)
      if defined?(I18n)
        I18n.t(key, **options, default: fallback(key, **options))
      else
        fallback(key, **options)
      end
    end

    # @param locale [Symbol, String] locale code
    #
    # @return [Hash] loaded translations
    #
    # @rbs (?Symbol locale) -> Hash[String, untyped]
    def self.translations(locale = :en)
      @translations ||= {}
      @translations[locale.to_s] ||= begin
        file = File.join(LOCALE_PATH, "#{locale}.yml")
        data = File.exist?(file) ? YAML.safe_load_file(file) : {}
        data[locale.to_s] || {}
      end
    end

    # @param key [String] dot-separated translation key
    # @param options [Hash] interpolation values
    #
    # @return [String] translated string or key as fallback
    #
    # @rbs (String key, **untyped options) -> String
    def self.fallback(key, **options)
      locale = options.delete(:locale) || :en
      keys = key.split(".")
      value = keys.reduce(translations(locale)) do |hash, k|
        break nil unless hash.is_a?(Hash)

        hash[k]
      end

      return key unless value.is_a?(String)

      options.reduce(value) do |str, (k, v)|
        str.gsub("%{#{k}}", v.to_s)
      end
    end

  end
end
