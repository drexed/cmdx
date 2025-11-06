# Module: CMDx::Validators::Presence
  
**Extended by:** CMDx::Validators::Presence
    

Validates that a value is present and not empty

This validator ensures that the given value exists and contains meaningful
content. It handles different value types appropriately:
*   Strings: checks for non-whitespace characters
*   Collections: checks for non-empty collections
*   Other objects: checks for non-nil values


# Class Methods
## call(value , options {}) [](#method-c-call)
Validates that a value is present and not empty
**@option** [] 

**@param** [Object] The value to validate for presence

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value is empty, nil, or contains only whitespace

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Presence.call("hello world")
# => nil (validation passes)
```
**@example**
```ruby
Presence.call("   ")
# => raises ValidationError
```
**@example**
```ruby
Presence.call([1, 2, 3])
# => nil (validation passes)
```
**@example**
```ruby
Presence.call([])
# => raises ValidationError
```
**@example**
```ruby
Presence.call(nil, message: "Value cannot be blank")
# => raises ValidationError with custom message
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Validates that a value is present and not empty

**@option** [] 

**@param** [Object] The value to validate for presence

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value is empty, nil, or contains only whitespace

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Presence.call("hello world")
# => nil (validation passes)
```
**@example**
```ruby
Presence.call("   ")
# => raises ValidationError
```
**@example**
```ruby
Presence.call([1, 2, 3])
# => nil (validation passes)
```
**@example**
```ruby
Presence.call([])
# => raises ValidationError
```
**@example**
```ruby
Presence.call(nil, message: "Value cannot be blank")
# => raises ValidationError with custom message
```