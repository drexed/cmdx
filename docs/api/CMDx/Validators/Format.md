# Module: CMDx::Validators::Format
  
**Extended by:** CMDx::Validators::Format
    

Validates that a value matches a specified format pattern

This validator ensures that the given value conforms to a specific format
using regular expressions. It supports both direct regex matching and
conditional matching with inclusion/exclusion patterns.


# Class Methods
## call(value , options {}) [](#method-c-call)
Validates that a value matches the specified format pattern
**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The value to validate for format compliance

**@param** [Hash, Regexp] Validation configuration options or direct regex pattern

**@raise** [ValidationError] When the value doesn't match the required format

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Format.call("user@example.com", /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
# => nil (validation passes)
```
**@example**
```ruby
Format.call("ABC123", with: /\A[A-Z]{3}\d{3}\z/)
# => nil (validation passes)
```
**@example**
```ruby
Format.call("hello", without: /\d/)
# => nil (validation passes - no digits)
```
**@example**
```ruby
Format.call("test123", with: /\A\w+\z/, without: /\A\d+\z/)
# => nil (validation passes - alphanumeric but not all digits)
```
**@example**
```ruby
Format.call("invalid", with: /\A\d+\z/, message: "Must contain only digits")
# => raises ValidationError with custom message
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Validates that a value matches the specified format pattern

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The value to validate for format compliance

**@param** [Hash, Regexp] Validation configuration options or direct regex pattern

**@raise** [ValidationError] When the value doesn't match the required format

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Format.call("user@example.com", /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
# => nil (validation passes)
```
**@example**
```ruby
Format.call("ABC123", with: /\A[A-Z]{3}\d{3}\z/)
# => nil (validation passes)
```
**@example**
```ruby
Format.call("hello", without: /\d/)
# => nil (validation passes - no digits)
```
**@example**
```ruby
Format.call("test123", with: /\A\w+\z/, without: /\A\d+\z/)
# => nil (validation passes - alphanumeric but not all digits)
```
**@example**
```ruby
Format.call("invalid", with: /\A\d+\z/, message: "Must contain only digits")
# => raises ValidationError with custom message
```