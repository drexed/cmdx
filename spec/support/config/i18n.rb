# frozen_string_literal: true

require "i18n"

I18n.load_path += Dir[File.expand_path("../../../lib/locales/*.{rb,yml}", __dir__)]

I18n.available_locales = %i[en] # TODO: get available locales from the I18n.load_path
I18n.enforce_available_locales = true
I18n.reload!

I18n.default_locale = :en
I18n.locale = :en
