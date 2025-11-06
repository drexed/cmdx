# Module: CMDx::Coercions::BigDecimal
  
**Extended by:** CMDx::Coercions::BigDecimal
    

Converts various input types to BigDecimal format

Handles conversion from numeric strings, integers, floats, and other values
that can be converted to BigDecimal using Ruby's BigDecimal() method.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a BigDecimal
**@option** [] 

**@param** [Object] The value to convert to BigDecimal

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to BigDecimal

**@return** [BigDecimal] The converted BigDecimal value


**@example**
```ruby
BigDecimal.call("123.45")                   # => #<BigDecimal:7f8b8c0d8e0f '0.12345E3',9(18)>
BigDecimal.call("0.001", precision: 6)      # => #<BigDecimal:7f8b8c0d8e0f '0.1E-2',9(18)>
```
**@example**
```ruby
BigDecimal.call(42)                         # => #<BigDecimal:7f8b8c0d8e0f '0.42E2',9(18)>
BigDecimal.call(3.14159)                    # => #<BigDecimal:7f8b8c0d8e0f '0.314159E1',9(18)>
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a BigDecimal

**@option** [] 

**@param** [Object] The value to convert to BigDecimal

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to BigDecimal

**@return** [BigDecimal] The converted BigDecimal value


**@example**
```ruby
BigDecimal.call("123.45")                   # => #<BigDecimal:7f8b8c0d8e0f '0.12345E3',9(18)>
BigDecimal.call("0.001", precision: 6)      # => #<BigDecimal:7f8b8c0d8e0f '0.1E-2',9(18)>
```
**@example**
```ruby
BigDecimal.call(42)                         # => #<BigDecimal:7f8b8c0d8e0f '0.42E2',9(18)>
BigDecimal.call(3.14159)                    # => #<BigDecimal:7f8b8c0d8e0f '0.314159E1',9(18)>
```