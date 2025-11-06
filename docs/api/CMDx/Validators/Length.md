# Module: CMDx::Validators::Length
  
**Extended by:** CMDx::Validators::Length
    

Validates the length of a value against various constraints.

This validator supports multiple length validation strategies including exact
length, minimum/maximum bounds, and range-based validation. It can be used to
ensure values meet specific length requirements for strings, arrays, and other
enumerable objects.


# Class Methods
## call(value , options {}) [](#method-c-call)
Validates a value's length against specified constraints.
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

**@option** [] 

**@option** [] 

**@param** [String, Array, Hash, Object] The value to validate (must respond to #length)

**@param** [Hash] Validation options

**@raise** [ValidationError] When validation fails

**@raise** [ArgumentError] When unknown validation options are provided

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Length.call("hello", is: 5)
# => nil (validation passes)
```
**@example**
```ruby
Length.call("test", within: 3..6)
# => nil (validation passes - length 4 is within range)
```
**@example**
```ruby
Length.call("username", min: 3, max: 20)
# => nil (validation passes - length 8 is between 3 and 20)
```
**@example**
```ruby
Length.call("short", not_in: 1..3)
# => nil (validation passes - length 5 is not in excluded range)
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Validates a value's length against specified constraints.

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

**@option** [] 

**@option** [] 

**@param** [String, Array, Hash, Object] The value to validate (must respond to #length)

**@param** [Hash] Validation options

**@raise** [ValidationError] When validation fails

**@raise** [ArgumentError] When unknown validation options are provided

**@return** [nil] Returns nil if validation passes


**@example**
```ruby
Length.call("hello", is: 5)
# => nil (validation passes)
```
**@example**
```ruby
Length.call("test", within: 3..6)
# => nil (validation passes - length 4 is within range)
```
**@example**
```ruby
Length.call("username", min: 3, max: 20)
# => nil (validation passes - length 8 is between 3 and 20)
```
**@example**
```ruby
Length.call("short", not_in: 1..3)
# => nil (validation passes - length 5 is not in excluded range)
```