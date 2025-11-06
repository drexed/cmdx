# Module: CMDx::Coercions::Rational
  
**Extended by:** CMDx::Coercions::Rational
    

Converts various input types to Rational format

Handles conversion from strings, numbers, and other values to rational numbers
using Ruby's Rational() method. Raises CoercionError for values that cannot be
converted to rational numbers.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a Rational
**@option** [] 

**@param** [Object] The value to convert to a rational number

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to a rational number

**@return** [Rational] The converted rational number


**@example**
```ruby
Rational.call("3/4")     # => (3/4)
Rational.call("2.5")     # => (5/2)
Rational.call("0")       # => (0/1)
```
**@example**
```ruby
Rational.call(3.14)      # => (157/50)
Rational.call(2)         # => (2/1)
Rational.call(0.5)       # => (1/2)
```
**@example**
```ruby
Rational.call("")        # => (0/1)
Rational.call(nil)       # => (0/1)
Rational.call(0)         # => (0/1)
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a Rational

**@option** [] 

**@param** [Object] The value to convert to a rational number

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [CoercionError] If the value cannot be converted to a rational number

**@return** [Rational] The converted rational number


**@example**
```ruby
Rational.call("3/4")     # => (3/4)
Rational.call("2.5")     # => (5/2)
Rational.call("0")       # => (0/1)
```
**@example**
```ruby
Rational.call(3.14)      # => (157/50)
Rational.call(2)         # => (2/1)
Rational.call(0.5)       # => (1/2)
```
**@example**
```ruby
Rational.call("")        # => (0/1)
Rational.call(nil)       # => (0/1)
Rational.call(0)         # => (0/1)
```