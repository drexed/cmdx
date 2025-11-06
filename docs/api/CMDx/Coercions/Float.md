# Module: CMDx::Coercions::Float
  
**Extended by:** CMDx::Coercions::Float
    

Converts various input types to Float format

Handles conversion from numeric strings, integers, and other numeric types
that can be converted to floats using Ruby's Float() method.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a Float
**@option** [] 

**@param** [Object] The value to convert to a float

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to a float

**@return** [Float] The converted float value


**@example**
```ruby
Float.call("123")        # => 123.0
Float.call("123.456")    # => 123.456
Float.call("-42.5")      # => -42.5
Float.call("1.23e4")     # => 12300.0
```
**@example**
```ruby
Float.call(42)           # => 42.0
Float.call(BigDecimal("123.456")) # => 123.456
Float.call(Rational(3, 4))       # => 0.75
Float.call(Complex(5.0, 0))      # => 5.0
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a Float

**@option** [] 

**@param** [Object] The value to convert to a float

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to a float

**@return** [Float] The converted float value


**@example**
```ruby
Float.call("123")        # => 123.0
Float.call("123.456")    # => 123.456
Float.call("-42.5")      # => -42.5
Float.call("1.23e4")     # => 12300.0
```
**@example**
```ruby
Float.call(42)           # => 42.0
Float.call(BigDecimal("123.456")) # => 123.456
Float.call(Rational(3, 4))       # => 0.75
Float.call(Complex(5.0, 0))      # => 5.0
```