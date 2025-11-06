# Module: CMDx::Utils::Format
  
**Extended by:** CMDx::Utils::Format
    

Utility module for formatting data structures into log-friendly strings and
converting messages to appropriate formats for logging


# Class Methods
## to_log(message ) [](#method-c-to_log)
Converts a message to a format suitable for logging
**@param** [Object] The message to format

**@return** [Hash, Object] Returns a hash if the message responds to to_h and is a CMDx object, otherwise returns the original message


**@example**
```ruby
Format.to_log({user_id: 123, action: "login"})
# => {user_id: 123, action: "login"}
```
**@example**
```ruby
Format.to_log("simple message")
# => "simple message"
```
**@example**
```ruby
Format.to_log(CMDx::Task.new(name: "task1"))
# => {name: "task1"}
```## to_str(hash , &block ) [](#method-c-to_str)
Converts a hash to a formatted string using a custom formatter
**@option** [] 

**@option** [] 

**@param** [Hash] The hash to convert to string

**@param** [Proc, nil] Optional custom formatter block

**@return** [String] Space-separated formatted key-value pairs


**@example**
```ruby
Format.to_str({user_id: 123, status: "active"})
# => "user_id=123 status=\"active\""
```
**@example**
```ruby
Format.to_str({count: 5, total: 100}) { |k, v| "#{k}:#{v}" }
# => "count:5 total:100"
```
# Instance Methods
## to_log(message) [](#method-i-to_log)
Converts a message to a format suitable for logging

**@param** [Object] The message to format

**@return** [Hash, Object] Returns a hash if the message responds to to_h and is a CMDx object, otherwise returns the original message


**@example**
```ruby
Format.to_log({user_id: 123, action: "login"})
# => {user_id: 123, action: "login"}
```
**@example**
```ruby
Format.to_log("simple message")
# => "simple message"
```
**@example**
```ruby
Format.to_log(CMDx::Task.new(name: "task1"))
# => {name: "task1"}
```## to_str(hash, &block) [](#method-i-to_str)
Converts a hash to a formatted string using a custom formatter

**@option** [] 

**@option** [] 

**@param** [Hash] The hash to convert to string

**@param** [Proc, nil] Optional custom formatter block

**@return** [String] Space-separated formatted key-value pairs


**@example**
```ruby
Format.to_str({user_id: 123, status: "active"})
# => "user_id=123 status=\"active\""
```
**@example**
```ruby
Format.to_str({count: 5, total: 100}) { |k, v| "#{k}:#{v}" }
# => "count:5 total:100"
```