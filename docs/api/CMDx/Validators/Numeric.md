# Module: CMDx::Validators::Numeric
  
**Extended by:** CMDx::Validators::Numeric
    

Validates numeric values against various constraints and ranges

This validator ensures that numeric values meet specified criteria such as
minimum/maximum bounds, exact matches, or range inclusions. It supports both
inclusive and exclusive range validations with customizable error messages.


# Class Methods
## call(value , options {}) [](#method-c-call)
Validates a numeric value against the specified options
**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Numeric] The numeric value to validate

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value fails validation

**@raise** [ArgumentError] When unknown validator options are provided

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Numeric.call(5, within: 1..10)
# => nil (validation passes)
```
**@example**
```ruby
Numeric.call(15, min: 10, max: 20)
# => nil (validation passes)
```
**@example**
```ruby
Numeric.call(42, is: 42)
# => nil (validation passes)
```
**@example**
```ruby
Numeric.call(5, not_in: 1..10)
# => nil (validation passes - 5 is not in 1..10)
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Validates a numeric value against the specified options

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Numeric] The numeric value to validate

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value fails validation

**@raise** [ArgumentError] When unknown validator options are provided

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Numeric.call(5, within: 1..10)
# => nil (validation passes)
```
**@example**
```ruby
Numeric.call(15, min: 10, max: 20)
# => nil (validation passes)
```
**@example**
```ruby
Numeric.call(42, is: 42)
# => nil (validation passes)
```
**@example**
```ruby
Numeric.call(5, not_in: 1..10)
# => nil (validation passes - 5 is not in 1..10)
```