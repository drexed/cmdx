# Class: CMDx::Chain
**Inherits:** Object
  
**Extended by:** Forwardable
    

Manages a collection of task execution results in a thread-safe manner. Chains
provide a way to track related task executions and their outcomes within the
same execution context.


# Class Methods
## build(result ) [](#method-c-build)
Builds or extends the current chain by adding a result. Creates a new chain if
none exists, otherwise appends to the current one.
**@param** [Result] The task execution result to add

**@raise** [TypeError] If result is not a CMDx::Result instance

**@return** [Chain] The current chain (newly created or existing)


**@example**
```ruby
result = task.execute
chain = Chain.build(result)
puts "Chain size: #{chain.size}"
```## clear() [](#method-c-clear)
Clears the current chain for the current thread.
**@return** [nil] Always returns nil


**@example**
```ruby
Chain.clear
```## current() [](#method-c-current)
Retrieves the current chain for the current thread.
**@return** [Chain, nil] The current chain or nil if none exists


**@example**
```ruby
chain = Chain.current
if chain
  puts "Current chain: #{chain.id}"
end
```## current=(chain ) [](#method-c-current=)
Sets the current chain for the current thread.
**@param** [Chain] The chain to set as current

**@return** [Chain] The set chain


**@example**
```ruby
Chain.current = my_chain
```# Attributes
## id[RW] [](#attribute-i-id)
Returns the unique identifier for this chain.

**@return** [String] The chain identifier


**@example**
```ruby
chain.id # => "abc123xyz"
```## results[RW] [](#attribute-i-results)
Returns the collection of execution results in this chain.

**@return** [Array<Result>] Array of task results


**@example**
```ruby
chain.results # => [#<Result>, #<Result>]
```
# Instance Methods
## initialize() [](#method-i-initialize)
Creates a new chain with a unique identifier and empty results collection.

**@return** [Chain] A new chain instance

## to_h() [](#method-i-to_h)
Converts the chain to a hash representation.

**@option** [] 

**@option** [] 

**@param** [Hash] a customizable set of options

**@return** [Hash] Hash containing chain id and serialized results


**@example**
```ruby
chain_hash = chain.to_h
puts chain_hash[:id]
puts chain_hash[:results].size
```## to_s() [](#method-i-to_s)
Converts the chain to a string representation.

**@return** [String] Formatted string representation of the chain


**@example**
```ruby
puts chain.to_s
```