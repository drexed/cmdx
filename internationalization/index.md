# Internationalization (i18n)

CMDx supports 90+ languages out of the box for all error messages, validations, coercions, and faults. Error messages automatically adapt to the current `I18n.locale`, making it easy to build applications for global audiences.

## Usage

All error messages are automatically localized based on your current locale:

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

CMDx uses the `I18n` gem for localization. In Rails, locales load automatically.

### Copy Locale Files

Copy locale files to your Rails application's `config/locales` directory:

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
