# Class: Cmdx::InstallGenerator
**Inherits:** Rails::Generators::Base
    

Generates CMDx initializer file for Rails applications

This generator creates a configuration initializer that sets up global CMDx
settings for the Rails application. It copies a pre-configured initializer
template to the standard Rails initializers directory.



# Instance Methods
## copy_initializer_file() [](#method-i-copy_initializer_file)
Copies the CMDx initializer template to the Rails application

Creates a new initializer file at `config/initializers/cmdx.rb` containing the
default CMDx configuration settings. This allows applications to customize
global CMDx behavior through the standard Rails configuration pattern.

**@return** [void] 


**@example**
```ruby
rails generate cmdx:install
```
**@example**
```ruby
generator.copy_initializer_file
# => Creates config/initializers/cmdx.rb
```