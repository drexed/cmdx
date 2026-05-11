# Internationalization (i18n)

CMDx talks to users through messages: coercion errors, validation errors, missing outputs, missing required inputs, and the default fault reason. **All of that** goes through `CMDx::I18nProxy`.

**If the `i18n` gem is loaded**, CMDx uses `I18n.translate`, so messages follow whatever `I18n.locale` is set to—just like the rest of your app.

**If `i18n` isn’t there**, CMDx loads YAML for `config.default_locale` and does simple `%{key}` interpolation itself.

Out of the box, CMDx ships **English only** (`en`). Want dozens more languages? Add [cmdx-i18n](https://github.com/drexed/cmdx-i18n), or drop in your own YAML (see [Custom locale paths](#custom-locale-paths)).

## Usage

Flip the locale and built-in messages follow:

```ruby
class ProcessQuote < CMDx::Task
  required :price, coerce: :float

  def work
    # ...
  end
end

I18n.with_locale(:fr) do
  result = ProcessQuote.execute(price: "invalid")
  result.failed?               #=> true
  result.errors[:price]        #=> ["impossible de contraindre en float"]
  result.reason                #=> "price impossible de contraindre en float"
end
```

Note

Failures pile up on `task.errors` (`CMDx::Errors`). `result.reason` is basically the friendly string built from those errors (`Errors#full_messages`, joined with `". "`).

## Translation Keys

Everything lives under `cmdx.*`. Override a key in **your** locale file to change wording app-wide:

| Key                                                                             | Used by                                                                                                                                                                    |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cmdx.attributes.required`                                                      | Missing required input                                                                                                                                                     |
| `cmdx.coercions.into_a` / `into_an`                                             | Single-type coercion failure (`%{type}`)                                                                                                                                   |
| `cmdx.coercions.into_any`                                                       | Multi-type coercion failure (`%{types}`)                                                                                                                                   |
| `cmdx.outputs.missing`                                                          | Declared output not set on context                                                                                                                                         |
| `cmdx.reasons.unspecified`                                                      | Fallback fault reason                                                                                                                                                      |
| `cmdx.types.<name>`                                                             | Human-readable coercion type names (`array`, `big_decimal`, `boolean`, `complex`, `date`, `date_time`, `float`, `hash`, `integer`, `rational`, `string`, `symbol`, `time`) |
| `cmdx.validators.absence` / `presence` / `format`                               | Standalone validator messages                                                                                                                                              |
| `cmdx.validators.inclusion.{of,within}`                                         | Inclusion validator messages                                                                                                                                               |
| `cmdx.validators.exclusion.{of,within}`                                         | Exclusion validator messages                                                                                                                                               |
| `cmdx.validators.length.{is,is_not,min,max,gt,lt,within,not_within,nil_value}`  | Length validator messages                                                                                                                                                  |
| `cmdx.validators.numeric.{is,is_not,min,max,gt,lt,within,not_within,nil_value}` | Numeric validator messages                                                                                                                                                 |

Tip

Tweaking **one** field? Use `:message` or `:<rule>_message` on the input (see [Validations](https://drexed.github.io/cmdx/inputs/validations/#common-options)). Overriding `cmdx.*` changes the text **everywhere** that key is used.

## Configuration

### Rails

The CMDx railtie adds its locale files to `I18n.load_path` on boot—but **only** for locales you list in `config.i18n.available_locales`. So you don’t load YAML for languages you never ship.

```ruby
# config/application.rb
config.i18n.available_locales = [:en, :fr, :es]
```

### Default locale (plain Ruby)

No `i18n` gem? (Scripts, CLIs, tiny workers.) Set `default_locale` and CMDx reads that locale’s YAML directly.

```ruby
CMDx.configure do |config|
  config.default_locale = "es"
end
```

In this mode there’s **one** active locale—no `I18n.with_locale` equivalent. If a key is missing, you’ll see `"Translation missing: <key>"`. If the **locale itself** can’t be resolved to a YAML file on the load path, CMDx raises `CMDx::UnknownLocaleError` (a `CMDx::Error`) the first time it tries to translate. More detail: [Configuration – default locale](https://drexed.github.io/cmdx/configuration/#default-locale).

### Custom locale paths

Point CMDx at extra folders of `<locale>.yml` files with `I18nProxy.register`. **Later** registrations win on merge, so you can override a few keys without copying entire files.

```ruby
# lib/locales/en.yml
en:
  cmdx:
    attributes:
      required: "is mandatory"

CMDx::I18nProxy.register(File.expand_path("lib/locales", __dir__))
```

Note

`register` only affects the **no-i18n-gem** path. When `i18n` is loaded, CMDx delegates to `I18n.translate`—add your paths to `I18n.load_path` instead.

## Available locales

The [cmdx-i18n](https://github.com/drexed/cmdx-i18n) gem bundles community translations for **85+** locales (Arabic, Chinese, French, German, Japanese, Portuguese, Spanish, and more). Add it to your `Gemfile` and those locales show up wherever CMDx calls `I18n.translate`. The gem’s README lists the exact set.
