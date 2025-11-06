# Class: Cmdx::LocaleGenerator
**Inherits:** Rails::Generators::Base
    

Generates CMDx locale files for Rails applications

Rails generator that copies CMDx locale files into the application's
config/locales directory. This allows applications to customize and extend the
default CMDx locale files.



# Instance Methods
## copy_locale_files() [](#method-i-copy_locale_files)
Copies the locale template to the Rails application

Copies the specified locale file from the gem's locales directory to the
application's config/locales directory. If the locale file doesn't exist in
the gem, the generator will fail gracefully.

**@return** [void] 


**@example**
```ruby
# Copy default (English) locale file
rails generate cmdx:locale
# => Creates config/locales/en.yml

# Copy Spanish locale file
rails generate cmdx:locale es
# => Creates config/locales/es.yml
```