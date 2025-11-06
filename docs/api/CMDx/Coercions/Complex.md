# Module: CMDx::Coercions::Complex
  
**Extended by:** CMDx::Coercions::Complex
    

Converts various input types to Complex number format

Handles conversion from numeric strings, integers, floats, and other values
that can be converted to Complex using Ruby's Complex() method.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a Complex number
**@param** [Object] The value to convert to Complex

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to Complex

**@return** [Complex] The converted Complex number value


**@example**
```ruby
Complex.call("3+4i")                     # => (3+4i)
Complex.call("2.5")                      # => (2.5+0i)
```
**@example**
```ruby
Complex.call(5)                          # => (5+0i)
Complex.call(3.14)                       # => (3.14+0i)
Complex.call(Complex(1, 2))              # => (1+2i)
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a Complex number

**@param** [Object] The value to convert to Complex

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to Complex

**@return** [Complex] The converted Complex number value


**@example**
```ruby
Complex.call("3+4i")                     # => (3+4i)
Complex.call("2.5")                      # => (2.5+0i)
```
**@example**
```ruby
Complex.call(5)                          # => (5+0i)
Complex.call(3.14)                       # => (3.14+0i)
Complex.call(Complex(1, 2))              # => (1+2i)
```