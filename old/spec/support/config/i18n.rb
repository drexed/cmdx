# frozen_string_literal: true

spec_path = Pathname.new(File.expand_path("../../../lib/locales", File.dirname(__FILE__)))
I18n.load_path += Dir[spec_path.join("*.yml")]

I18n.enforce_available_locales = true
I18n.reload!

I18n.default_locale = :en
I18n.locale = :en
