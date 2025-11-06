# Module: CMDx::Coercions::Symbol
  
**Extended by:** CMDx::Coercions::Symbol
    

Coerces values to Symbol type using Ruby's to_sym method.

This coercion handles various input types by converting them to symbols. It
provides error handling for values that cannot be converted to symbols and
raises appropriate CMDx coercion errors with localized messages.


# Class Methods
## call(value , options {}) [](#method-c-call)
Coerces a value to Symbol type.
**@param** [Object] The value to coerce to a symbol

**@param** [Hash] Optional configuration parameters (unused in this coercion)

**@raise** [CoercionError] If the value cannot be converted to a symbol

**@return** [Symbol] The coerced symbol value


**@example**
```ruby
Symbol.call("hello")           # => :hello
Symbol.call("user_id")         # => :user_id
Symbol.call("")                # => :""
Symbol.call(:existing)         # => :existing
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Coerces a value to Symbol type.

**@param** [Object] The value to coerce to a symbol

**@param** [Hash] Optional configuration parameters (unused in this coercion)

**@raise** [CoercionError] If the value cannot be converted to a symbol

**@return** [Symbol] The coerced symbol value


**@example**
```ruby
Symbol.call("hello")           # => :hello
Symbol.call("user_id")         # => :user_id
Symbol.call("")                # => :""
Symbol.call(:existing)         # => :existing
```