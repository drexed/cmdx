# Module: CMDx::Coercions::Boolean
  
**Extended by:** CMDx::Coercions::Boolean
    

Converts various input types to Boolean format

Handles conversion from strings, numbers, and other values to boolean using
predefined truthy and falsey patterns.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a Boolean
**@option** [] 

**@param** [Object] The value to convert to boolean

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to boolean

**@return** [Boolean] The converted boolean value


**@example**
```ruby
Boolean.call("true")   # => true
Boolean.call("yes")    # => true
Boolean.call("1")      # => true
```
**@example**
```ruby
Boolean.call("false")  # => false
Boolean.call("no")     # => false
Boolean.call("0")      # => false
```
**@example**
```ruby
Boolean.call("TRUE")   # => true
Boolean.call("False")  # => false
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a Boolean

**@option** [] 

**@param** [Object] The value to convert to boolean

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to boolean

**@return** [Boolean] The converted boolean value


**@example**
```ruby
Boolean.call("true")   # => true
Boolean.call("yes")    # => true
Boolean.call("1")      # => true
```
**@example**
```ruby
Boolean.call("false")  # => false
Boolean.call("no")     # => false
Boolean.call("0")      # => false
```
**@example**
```ruby
Boolean.call("TRUE")   # => true
Boolean.call("False")  # => false
```