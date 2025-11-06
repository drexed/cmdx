# Module: CMDx::Coercions::Integer
  
**Extended by:** CMDx::Coercions::Integer
    

Converts various input types to Integer format

Handles conversion from strings, numbers, and other values to integers using
Ruby's Integer() method. Raises CoercionError for values that cannot be
converted to integers.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to an Integer
**@option** [] 

**@param** [Object] The value to convert to an integer

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to an integer

**@return** [Integer] The converted integer value


**@example**
```ruby
Integer.call("42")      # => 42
Integer.call("-123")    # => -123
Integer.call("0")       # => 0
```
**@example**
```ruby
Integer.call(42.0)      # => 42
Integer.call(3.14)      # => 3
Integer.call(0.0)       # => 0
```
**@example**
```ruby
Integer.call("")        # => 0
Integer.call(nil)       # => 0
Integer.call(false)     # => 0
Integer.call(true)      # => 1
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to an Integer

**@option** [] 

**@param** [Object] The value to convert to an integer

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to an integer

**@return** [Integer] The converted integer value


**@example**
```ruby
Integer.call("42")      # => 42
Integer.call("-123")    # => -123
Integer.call("0")       # => 0
```
**@example**
```ruby
Integer.call(42.0)      # => 42
Integer.call(3.14)      # => 3
Integer.call(0.0)       # => 0
```
**@example**
```ruby
Integer.call("")        # => 0
Integer.call(nil)       # => 0
Integer.call(false)     # => 0
Integer.call(true)      # => 1
```