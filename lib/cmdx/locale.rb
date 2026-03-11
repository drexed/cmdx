# frozen_string_literal: true

module CMDx
  # Provides internationalization and localization support for CMDx.
  # Handles translation lookups with fallback to the configured locale's
  # default messages when I18n gem is not available.
  module Locale

    extend self

    # Translates a key to the current locale with optional interpolation.
    # Falls back to the configured locale's YAML file translations if
    # I18n gem is unavailable.
    #
    # @param key [String, Symbol] The translation key (supports dot notation)
    # @param options [Hash] Translation options
    # @option options [String] :default Fallback message if translation missing
    # @option options [String] :locale Target locale (when I18n available)
    # @option options [Hash] :scope Translation scope (when I18n available)
    # @option options [Object] :* Any other options passed to I18n.t or string interpolation
    #
    # @return [String] The translated message
    #
    # @raise [ArgumentError] When interpolation fails due to missing keys
    #
    # @example Basic translation
    #   Locale.translate("errors.invalid_input")
    #   # => "Invalid input provided"
    # @example With interpolation
    #   Locale.translate("welcome.message", name: "John")
    #   # => "Welcome, John!"
    # @example With fallback
    #   Locale.translate("missing.key", default: "Custom fallback message")
    #   # => "Custom fallback message"
    #
    # @rbs ((String | Symbol) key, **untyped options) -> String
    def translate(key, **options)
      options[:default] ||= translation_default(key)
      return ::I18n.t(key, **options) if defined?(::I18n)

      case message = options.delete(:default)
      when String then message % options
      when NilClass then "Translation missing: #{key}"
      else message
      end
    end

    # @see #translate
    alias t translate

    private

    # Resolves and caches the default translation for a key by digging
    # into the configured locale's YAML translations.
    #
    # @param key [String, Symbol] The translation key
    #
    # @return [String, nil] The resolved translation or nil
    #
    # @rbs ((String | Symbol) key) -> String?
    def translation_default(key)
      tkey = "#{CMDx.configuration.default_locale}.#{key}"

      @translation_defaults ||= {}
      return @translation_defaults[tkey] if @translation_defaults.key?(tkey)

      @default_translations ||= begin
        path = CMDx.gem_path.join("lib/locales/#{CMDx.configuration.default_locale}.yml")
        raise ArgumentError, "locale file not found: #{path}" unless path.exist?

        YAML.load_file(path).freeze
      end

      @translation_defaults[tkey] = @default_translations.dig(*tkey.split("."))
    end

  end
end
