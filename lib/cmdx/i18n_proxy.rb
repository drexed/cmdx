# frozen_string_literal: true

module CMDx
  # Translation façade used internally for coercion, validator, and output
  # error messages. Delegates to `I18n.translate` when the `i18n` gem is
  # available; otherwise loads CMDx's bundled YAML locale file and performs
  # percent-interpolation on the string itself. Results are memoized.
  class I18nProxy

    class << self

      # @return [Array<String>] directories searched (in order) for bundled locale YAMLs
      def locale_paths
        @locale_paths ||= [File.expand_path("../locales", __dir__)]
      end

      # @param key [String, Symbol] dot-separated translation key
      # @param options [Hash{Symbol => Object}] interpolation values (e.g. `type:`)
      # @return [String, Object] the translated string (or the raw default value)
      def translate(key, **options)
        @proxy ||= new
        @proxy.translate(key, **options)
      end
      alias t translate

      # Register an additional directory containing locale YAML files. Later
      # registrations take precedence over earlier ones (the most recently
      # registered path's values win during deep merge). Resets the memoized
      # proxy so subsequent lookups see the new path.
      #
      # @param path [String] absolute path to a directory of `<locale>.yml` files
      # @return [Array<String>] the updated locale paths
      def register(path)
        locale_paths.push(path) unless locale_paths.include?(path)
        @proxy = nil
        locale_paths
      end

      # Resolves a reason string through translation, falling back to either
      # the literal reason (when present) or the `cmdx.reasons.unspecified`
      # default (when nil).
      #
      # @param reason [String, Symbol, nil] reason text or translation key
      # @return [String] translated message, literal reason, or default
      def tr(reason)
        translate(reason || "cmdx.reasons.unspecified", default: reason)
      end

    end

    # @param key [String, Symbol] dot-separated translation key
    # @param options [Hash{Symbol => Object}] interpolation values
    # @return [String, Object] the translated/interpolated message
    def translate(key, **options)
      return ::I18n.translate(key, **options) if defined?(::I18n) && ::I18n.respond_to?(:translate)

      message = translation_default(key) || options[:default]

      case message
      when String
        message % options
      when NilClass
        "Translation missing: #{key}"
      else
        message
      end
    end
    alias t translate

    private

    def translation_default(key)
      default_locale  = CMDx.configuration.default_locale || "en"
      translation_key = "#{default_locale}.#{key}"

      @defaults ||= {}
      return @defaults[translation_key] if @defaults.key?(translation_key)

      @translations ||= {}
      @translations[default_locale] ||= begin
        file = "#{default_locale}.yml"
        paths = self.class.locale_paths.map { |dir| File.join(dir, file) }.select { |p| File.exist?(p) }
        raise LoadError, "unable to load #{default_locale} translations" if paths.empty?

        paths.reduce({}) { |hash, path| hash.merge(YAML.safe_load_file(path)) }.freeze
      end

      @defaults[translation_key] = @translations[default_locale].dig(*translation_key.split("."))
    end

  end
end
