# Module: CMDx::Validators::Inclusion
  
**Extended by:** CMDx::Validators::Inclusion
    

Validates that a value is included in a specified set or range

This validator ensures that the given value is present within a collection of
allowed values or falls within a specified range. It supports both discrete
value lists and range-based validations.


# Class Methods
## call(value , options {}) [](#method-c-call)
Validates that a value is included in the specified options
**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The value to validate for inclusion

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value is not found in the allowed collection

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Inclusion.call("admin", in: ["admin", "user", "guest"])
# => nil (validation passes)
```
**@example**
```ruby
Inclusion.call(5, in: 1..10)
# => nil (validation passes - 5 is within 1..10)
```
**@example**
```ruby
Inclusion.call("test", in: ["admin", "user"], message: "must be one of: %{values}")
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Validates that a value is included in the specified options

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The value to validate for inclusion

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value is not found in the allowed collection

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Inclusion.call("admin", in: ["admin", "user", "guest"])
# => nil (validation passes)
```
**@example**
```ruby
Inclusion.call(5, in: 1..10)
# => nil (validation passes - 5 is within 1..10)
```
**@example**
```ruby
Inclusion.call("test", in: ["admin", "user"], message: "must be one of: %{values}")
```