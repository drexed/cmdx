# Internationalization (i18n)

CMDx provides comprehensive internationalization support for all error messages, attribute validation failures, coercion errors, and fault messages. All user-facing text is automatically localized based on the current `I18n.locale`, ensuring your applications can serve global audiences with native-language error reporting.

## Table of Contents

- [Localization](#localization)
- [Configuration](#configuration)
  - [Local Copies](#local-copies)
  - [Available Locales](#available-locales)

## Localization

CMDx automatically localizes all error messages based on the `I18n.locale` setting.

```ruby
class ProcessQuote < CMDx::Task
  attribute :price, type: :float

  def work
    # Your logic here...
  end
end

I18n.with_locale(:fr) do
  result = ProcessQuote.execute(price: "invalid")
  result.metadata[:messages][:price] #=> ["impossible de contraindre en float"]
end
```

## Configuration

Localization is handled by the `I18n` gem. In Rails applications, locales are loaded automatically and managed via the `I18n.available_locales` setting.

### Local Copies

Execute the following command to copy any locale into the Rails applications `config/locales` directory:

```bash
rails generate cmdx:locale [LOCALE]

# Eg: generate french locale
rails generate cmdx:locale fr
```

### Available Locales

- af - Afrikaans
- ar - Arabic
- az - Azerbaijani
- be - Belarusian
- bg - Bulgarian
- bn - Bengali
- bs - Bosnian
- ca - Catalan
- cnr - Montenegrin
- cs - Czech
- cy - Welsh
- da - Danish
- de - German
- dz - Dzongkha
- el - Greek
- en - English
- eo - Esperanto
- es - Spanish
- et - Estonian
- eu - Basque
- fa - Persian
- fi - Finnish
- fr - French
- fy - Western Frisian
- gd - Scottish Gaelic
- gl - Galician
- he - Hebrew
- hi - Hindi
- hr - Croatian
- hu - Hungarian
- hy - Armenian
- id - Indonesian
- is - Icelandic
- it - Italian
- ja - Japanese
- ka - Georgian
- kk - Kazakh
- km - Khmer
- kn - Kannada
- ko - Korean
- lb - Luxembourgish
- lo - Lao
- lt - Lithuanian
- lv - Latvian
- mg - Malagasy
- mk - Macedonian
- ml - Malayalam
- mn - Mongolian
- mr-IN - Marathi (India)
- ms - Malay
- nb - Norwegian Bokmål
- ne - Nepali
- nl - Dutch
- nn - Norwegian Nynorsk
- oc - Occitan
- or - Odia
- pa - Punjabi
- pl - Polish
- pt - Portuguese
- rm - Romansh
- ro - Romanian
- ru - Russian
- sc - Sardinian
- sk - Slovak
- sl - Slovenian
- sq - Albanian
- sr - Serbian
- st - Southern Sotho
- sv - Swedish
- sw - Swahili
- ta - Tamil
- te - Telugu
- th - Thai
- tl - Tagalog
- tr - Turkish
- tt - Tatar
- ug - Uyghur
- uk - Ukrainian
- ur - Urdu
- uz - Uzbek
- vi - Vietnamese
- wo - Wolof
- zh-CN - Chinese (Simplified)
- zh-HK - Chinese (Hong Kong)
- zh-TW - Chinese (Traditional)
- zh-YUE - Chinese (Yue)

---

- **Prev:** [Logging](logging.md)
- **Next:** [Deprecation](deprecation.md)
