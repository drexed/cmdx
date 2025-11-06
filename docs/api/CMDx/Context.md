# Class: CMDx::Context
**Inherits:** Object
  
**Extended by:** Forwardable
    

A hash-like context object that provides a flexible way to store and access
key-value pairs during task execution. Keys are automatically converted to
symbols for consistency.

The Context class extends Forwardable to delegate common hash methods and
provides additional convenience methods for working with context data.


# Class Methods
## build(context {}) [](#method-c-build)
Builds a Context instance, reusing existing unfrozen contexts when possible.
**@option** [] 

**@param** [Context, Object] the context to build from

**@return** [Context] a Context instance, either new or reused


**@example**
```ruby
existing = Context.new(name: "John")
built = Context.build(existing) # reuses existing context
built.object_id == existing.object_id # => true
```# Attributes
## table[RW] [](#attribute-i-table)
Returns the internal hash storing context data.

**@return** [Hash{Symbol => Object}] The internal hash table


**@example**
```ruby
context.table # => { name: "John", age: 30 }
```
# Instance Methods
## [](key) [](#method-i-[])
Retrieves a value from the context by key.

**@param** [String, Symbol] the key to retrieve

**@return** [Object, nil] the value associated with the key, or nil if not found


**@example**
```ruby
context = Context.new(name: "John")
context[:name] # => "John"
context["name"] # => "John" (automatically converted to symbol)
```## delete!(key) [](#method-i-delete!)
Deletes a key-value pair from the context.

**@param** [String, Symbol] the key to delete

**@return** [Object, nil] the deleted value, or the block result if key not found

**@yield** [key] a block to handle the case when key is not found


**@example**
```ruby
context = Context.new(name: "John", age: 30)
context.delete!(:age) # => 30
context.delete!(:city) { |key| "Key #{key} not found" } # => "Key city not found"
```## dig(key, *keys) [](#method-i-dig)
Digs into nested structures using the given keys.

**@param** [String, Symbol] the first key to dig with

**@param** [Array<String, Symbol>] additional keys for deeper digging

**@return** [Object, nil] the value found by digging, or nil if not found


**@example**
```ruby
context = Context.new(user: {profile: {name: "John"}})
context.dig(:user, :profile, :name) # => "John"
context.dig(:user, :profile, :age) # => nil
```## eql?(other) [](#method-i-eql?)
Compares this context with another object for equality.

**@param** [Object] the object to compare with

**@return** [Boolean] true if other is a Context with the same data


**@example**
```ruby
context1 = Context.new(name: "John")
context2 = Context.new(name: "John")
context1 == context2 # => true
```## fetch(key) [](#method-i-fetch)
Fetches a value from the context by key, with optional default value.

**@param** [String, Symbol] the key to fetch

**@param** [Object] the default value if key is not found

**@return** [Object] the value associated with the key, or the default/default block result

**@yield** [key] a block to compute the default value


**@example**
```ruby
context = Context.new(name: "John")
context.fetch(:name) # => "John"
context.fetch(:age, 25) # => 25
context.fetch(:city) { |key| "Unknown #{key}" } # => "Unknown city"
```## fetch_or_store(key, valuenil) [](#method-i-fetch_or_store)
Fetches a value from the context by key, or stores and returns a default value
if not found.

**@param** [String, Symbol] the key to fetch or store

**@param** [Object] the default value to store if key is not found

**@return** [Object] the existing value if key is found, otherwise the stored default value

**@yield** [key] a block to compute the default value to store


**@example**
```ruby
context = Context.new(name: "John")
context.fetch_or_store(:name, "Default") # => "John" (existing value)
context.fetch_or_store(:age, 25) # => 25 (stored and returned)
context.fetch_or_store(:city) { |key| "Unknown #{key}" } # => "Unknown city" (stored and returned)
```## initialize(args{}) [](#method-i-initialize)
Creates a new Context instance from the given arguments.

**@option** [] 

**@param** [Hash, Object] arguments to initialize the context with

**@raise** [ArgumentError] when args doesn't respond to `to_h` or `to_hash`

**@return** [Context] a new Context instance


**@example**
```ruby
context = Context.new(name: "John", age: 30)
context[:name] # => "John"
```## key?(key) [](#method-i-key?)
Checks if the context contains a specific key.

**@param** [String, Symbol] the key to check

**@return** [Boolean] true if the key exists in the context


**@example**
```ruby
context = Context.new(name: "John")
context.key?(:name) # => true
context.key?(:age) # => false
```## merge!(args{}) [](#method-i-merge!)
Merges the given arguments into the current context, modifying it in place.

**@option** [] 

**@param** [Hash, Object] arguments to merge into the context

**@return** [Context] self for method chaining


**@example**
```ruby
context = Context.new(name: "John")
context.merge!(age: 30, city: "NYC")
context.to_h # => {name: "John", age: 30, city: "NYC"}
```## store(key, value) [](#method-i-store)
Stores a key-value pair in the context.

**@param** [String, Symbol] the key to store

**@param** [Object] the value to store

**@return** [Object] the stored value


**@example**
```ruby
context = Context.new
context.store(:name, "John")
context[:name] # => "John"
```## to_s() [](#method-i-to_s)
Converts the context to a string representation.

**@return** [String] a formatted string representation of the context data


**@example**
```ruby
context = Context.new(name: "John", age: 30)
context.to_s # => "name: John, age: 30"
```