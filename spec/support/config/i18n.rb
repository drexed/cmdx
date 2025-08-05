# frozen_string_literal: true

require "i18n"

locales = Dir[CMDx.gem_path.join("lib/locales/*.yml")]

I18n.load_path += locales
I18n.available_locales = locales.map { |path| File.basename(path, ".yml").to_sym }
I18n.enforce_available_locales = true
I18n.reload!

I18n.default_locale = :en
I18n.locale = :en
