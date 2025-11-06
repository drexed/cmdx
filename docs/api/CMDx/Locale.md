# Module: CMDx::Locale
  
**Extended by:** CMDx::Locale
    

Provides internationalization and localization support for CMDx. Handles
translation lookups with fallback to default English messages when I18n gem is
not available.


# Class Methods
## translate(key , **options ) [](#method-c-translate)
Translates a key to the current locale with optional interpolation. Falls back
to English translations if I18n gem is unavailable.
**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [String, Symbol] The translation key (supports dot notation)

**@param** [Hash] Translation options

**@raise** [ArgumentError] When interpolation fails due to missing keys

**@return** [String] The translated message


**@example**
```ruby
Locale.translate("errors.invalid_input")
# => "Invalid input provided"
```
**@example**
```ruby
Locale.translate("welcome.message", name: "John")
# => "Welcome, John!"
```
**@example**
```ruby
Locale.translate("missing.key", default: "Custom fallback message")
# => "Custom fallback message"
```
# Instance Methods
## translate(key, **options) [](#method-i-translate)
Translates a key to the current locale with optional interpolation. Falls back
to English translations if I18n gem is unavailable.

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [String, Symbol] The translation key (supports dot notation)

**@param** [Hash] Translation options

**@raise** [ArgumentError] When interpolation fails due to missing keys

**@return** [String] The translated message


**@example**
```ruby
Locale.translate("errors.invalid_input")
# => "Invalid input provided"
```
**@example**
```ruby
Locale.translate("welcome.message", name: "John")
# => "Welcome, John!"
```
**@example**
```ruby
Locale.translate("missing.key", default: "Custom fallback message")
# => "Custom fallback message"
```