# Internationalization (i18n)

All built-in messages — coercion errors, validation errors, output verification, required-input errors, and the fallback fault reason — are routed through `CMDx::I18nProxy`. When the `i18n` gem is loaded, CMDx delegates to `I18n.translate` and messages adapt automatically to the current `I18n.locale`. Otherwise, CMDx loads the YAML for `config.default_locale` in-process and percent-interpolates.

CMDx itself ships only `en`. Install [cmdx-i18n](https://github.com/drexed/cmdx-i18n) for 85+ additional translations, or register your own locale directory (see [Custom Locale Paths](#custom-locale-paths)).

## Usage

All built-in messages are localized via the current locale:

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

Coercion and validation failures accumulate on `task.errors` (a `CMDx::Errors` instance). `result.reason` is built from `errors.to_s` (`Errors#full_messages` joined with `". "`).

## Translation Keys

All CMDx built-ins live under the `cmdx.*` namespace. Override any key in your own locale files to customize messages app-wide:

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

Prefer the per-input `:message` / `:<rule>_message` option (see [Validations](https://drexed.github.io/cmdx/inputs/validations/#common-options)) when you only need to customize one attribute. Overriding the `cmdx.*` key changes the message everywhere.

## Configuration

### Rails

The CMDx railtie appends its bundled locale files to `I18n.load_path` on boot — but only for locales listed in `config.i18n.available_locales`, so you don't pay for translations you don't ship:

```ruby
# config/application.rb
config.i18n.available_locales = [:en, :fr, :es]
```

### Default Locale (plain Ruby)

Without the `i18n` gem (e.g. scripts, CLIs, background workers with no Rails), CMDx loads the YAML for `config.default_locale` directly:

```ruby
CMDx.configure do |config|
  config.default_locale = "es"
end
```

Only one locale is active at a time in this mode — there is no `I18n.with_locale` equivalent. If the key is absent, `I18nProxy#translate` returns `"Translation missing: <key>"`. See [Configuration](https://drexed.github.io/cmdx/configuration/#default-locale) for more details.

### Custom Locale Paths

Register additional directories of `<locale>.yml` files with `I18nProxy.register`. Later registrations take precedence during deep-merge, so you can override individual keys without copying the whole file:

```ruby
# lib/locales/en.yml
en:
  cmdx:
    attributes:
      required: "is mandatory"

CMDx::I18nProxy.register(File.expand_path("lib/locales", __dir__))
```

Note

`register` only affects the plain-Ruby fallback. When the `i18n` gem is loaded, CMDx delegates to `I18n.translate` and these paths are ignored — add your directories to `I18n.load_path` instead.

## Available Locales

The [cmdx-i18n](https://github.com/drexed/cmdx-i18n) companion gem provides community-maintained translations for 85+ locales (Arabic, Chinese, French, German, Japanese, Portuguese, Spanish, and more). Add it to your `Gemfile` and the locales become available to `I18n.translate` wherever CMDx is used; see the gem's README for the authoritative list.
