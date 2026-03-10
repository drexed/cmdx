# frozen_string_literal: true

module CMDx
  # Provides internationalization and localization support for CMDx.
  # Handles translation lookups with fallback to default English messages
  # when I18n gem is not available.
  module Locale

    extend self

    # Returns the lazily-loaded English translations hash.
    #
    # @return [Hash{String => Object}] The parsed English translations
    #
    # @rbs () -> Hash[String, untyped]
    def translations
      @translations ||= YAML.load_file(CMDx.gem_path.join("lib/locales/en.yml"))
    end

    # Translates a key to the current locale with optional interpolation.
    # Falls back to English translations if I18n gem is unavailable.
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
      options[:default] ||= translations.dig("en", *key.to_s.split("."))
      return ::I18n.t(key, **options) if defined?(::I18n)

      case message = options.delete(:default)
      when NilClass then "Translation missing: #{key}"
      when String then message % options
      else message
      end
    end

    # @see #translate
    alias t translate

  end
end
