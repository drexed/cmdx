# Module: CMDx::Coercions::String
  
**Extended by:** CMDx::Coercions::String
    

Coerces values to String type using Ruby's built-in String() method.

This coercion handles various input types by converting them to their string
representation. It's a simple wrapper around Ruby's String() method for
consistency with the CMDx coercion interface.


# Class Methods
## call(value , options {}) [](#method-c-call)
Coerces a value to String type.
**@param** [Object] The value to coerce to a string

**@param** [Hash] Optional configuration parameters (unused in this coercion)

**@raise** [TypeError] If the value cannot be converted to a string

**@return** [String] The coerced string value


**@example**
```ruby
String.call("hello")           # => "hello"
String.call(42)                # => "42"
String.call([1, 2, 3])         # => "[1, 2, 3]"
String.call(nil)               # => ""
String.call(true)              # => "true"
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Coerces a value to String type.

**@param** [Object] The value to coerce to a string

**@param** [Hash] Optional configuration parameters (unused in this coercion)

**@raise** [TypeError] If the value cannot be converted to a string

**@return** [String] The coerced string value


**@example**
```ruby
String.call("hello")           # => "hello"
String.call(42)                # => "42"
String.call([1, 2, 3])         # => "[1, 2, 3]"
String.call(nil)               # => ""
String.call(true)              # => "true"
```