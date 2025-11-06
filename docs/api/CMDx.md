# Module: CMDx
  
**Extended by:** CMDx
    



# Class Methods
## configuration() [](#method-c-configuration)
Returns the global configuration instance, creating it if it doesn't exist.
**@return** [Configuration] the global configuration instance


**@example**
```ruby
config = CMDx.configuration
config.middlewares # => #<MiddlewareRegistry>
```## configure() [](#method-c-configure)
Configures CMDx using a block that receives the configuration instance.
**@param** [Proc] the configuration block

**@raise** [ArgumentError] when no block is provided

**@return** [Configuration] the configured configuration instance

**@yield** [Configuration] the configuration instance to configure


**@example**
```ruby
CMDx.configure do |config|
  config.task_breakpoints = ["failed", "skipped"]
  config.logger.level = Logger::DEBUG
end
```## gem_path() [](#method-c-gem_path)
Returns the path to the CMDx gem.
**@return** [Pathname] the path to the CMDx gem


**@example**
```ruby
CMDx.gem_path # => Pathname.new("/path/to/cmdx")
```## reset_configuration!() [](#method-c-reset_configuration!)
Resets the global configuration to a new instance with default values.
**@return** [Configuration] the new configuration instance


**@example**
```ruby
CMDx.reset_configuration!
# Configuration is now reset to defaults
```
# Instance Methods
## configuration() [](#method-i-configuration)
Returns the global configuration instance, creating it if it doesn't exist.

**@return** [Configuration] the global configuration instance


**@example**
```ruby
config = CMDx.configuration
config.middlewares # => #<MiddlewareRegistry>
```## configure() [](#method-i-configure)
Configures CMDx using a block that receives the configuration instance.

**@param** [Proc] the configuration block

**@raise** [ArgumentError] when no block is provided

**@return** [Configuration] the configured configuration instance

**@yield** [Configuration] the configuration instance to configure


**@example**
```ruby
CMDx.configure do |config|
  config.task_breakpoints = ["failed", "skipped"]
  config.logger.level = Logger::DEBUG
end
```## gem_path() [](#method-i-gem_path)
Returns the path to the CMDx gem.

**@return** [Pathname] the path to the CMDx gem


**@example**
```ruby
CMDx.gem_path # => Pathname.new("/path/to/cmdx")
```## reset_configuration!() [](#method-i-reset_configuration!)
Resets the global configuration to a new instance with default values.

**@return** [Configuration] the new configuration instance


**@example**
```ruby
CMDx.reset_configuration!
# Configuration is now reset to defaults
```