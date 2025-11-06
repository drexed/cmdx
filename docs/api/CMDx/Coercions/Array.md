# Module: CMDx::Coercions::Array
  
**Extended by:** CMDx::Coercions::Array
    

Converts various input types to Array format

Handles conversion from strings that look like JSON arrays and other values
that can be converted to arrays using Ruby's Array() method.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to an Array
**@option** [] 

**@param** [Object] The value to convert to an array

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [JSON::ParserError] If the string value contains invalid JSON

**@return** [Array] The converted array value


**@example**
```ruby
Array.call("[1, 2, 3]") # => [1, 2, 3]
```
**@example**
```ruby
Array.call("hello")     # => ["hello"]
Array.call(42)          # => [42]
Array.call(nil)         # => []
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to an Array

**@option** [] 

**@param** [Object] The value to convert to an array

**@param** [Hash] Optional configuration parameters (currently unused)

**@raise** [JSON::ParserError] If the string value contains invalid JSON

**@return** [Array] The converted array value


**@example**
```ruby
Array.call("[1, 2, 3]") # => [1, 2, 3]
```
**@example**
```ruby
Array.call("hello")     # => ["hello"]
Array.call(42)          # => [42]
Array.call(nil)         # => []
```