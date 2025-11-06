# Module: CMDx::Coercions::Hash
  
**Extended by:** CMDx::Coercions::Hash
    

Coerces various input types into Hash objects

Supports conversion from:
*   Nil values (converted to empty Hash)
*   Hash objects (returned as-is)
*   Array objects (converted using [Hash](*array))
*   JSON strings starting with "{" (parsed into Hash)
*   Other types raise CoercionError


# Class Methods
## call(value , options {}) [](#method-c-call)
Coerces a value into a Hash
**@option** [] 

**@param** [Object] The value to coerce

**@param** [Hash] Additional options (currently unused)

**@raise** [CoercionError] When the value cannot be coerced to a Hash

**@return** [Hash] The coerced hash value


**@example**
```ruby
Hash.call({a: 1, b: 2}) # => {a: 1, b: 2}
```
**@example**
```ruby
Hash.call([:a, 1, :b, 2]) # => {a: 1, b: 2}
```
**@example**
```ruby
Hash.call('{"key": "value"}') # => {"key" => "value"}
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Coerces a value into a Hash

**@option** [] 

**@param** [Object] The value to coerce

**@param** [Hash] Additional options (currently unused)

**@raise** [CoercionError] When the value cannot be coerced to a Hash

**@return** [Hash] The coerced hash value


**@example**
```ruby
Hash.call({a: 1, b: 2}) # => {a: 1, b: 2}
```
**@example**
```ruby
Hash.call([:a, 1, :b, 2]) # => {a: 1, b: 2}
```
**@example**
```ruby
Hash.call('{"key": "value"}') # => {"key" => "value"}
```