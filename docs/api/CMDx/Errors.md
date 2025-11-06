# Class: CMDx::Errors
**Inherits:** Object
  
**Extended by:** Forwardable
    

Collection of validation and execution errors organized by attribute. Provides
methods to add, query, and format error messages for different attributes in a
task or workflow execution.


# Attributes
## messages[RW] [](#attribute-i-messages)
Returns the internal hash of error messages by attribute.

**@return** [Hash{Symbol => Set<String>}] Hash mapping attribute names to error message sets


**@example**
```ruby
errors.messages # => { email: #<Set: ["must be valid", "is required"]> }
```
# Instance Methods
## add(attribute, message) [](#method-i-add)
Add an error message for a specific attribute.

**@param** [Symbol] The attribute name associated with the error

**@param** [String] The error message to add


**@example**
```ruby
errors = CMDx::Errors.new
errors.add(:email, "must be valid format")
errors.add(:email, "cannot be blank")
```## for?(attribute) [](#method-i-for?)
Check if there are any errors for a specific attribute.

**@param** [Symbol] The attribute name to check for errors

**@return** [Boolean] true if the attribute has errors, false otherwise


**@example**
```ruby
errors.for?(:email) # => true
errors.for?(:name)  # => false
```## full_messages() [](#method-i-full_messages)
Convert errors to a hash format with arrays of full messages.

**@return** [Hash{Symbol => Array<String>}] Hash with attribute keys and message arrays


**@example**
```ruby
errors.full_messages # => { email: ["email must be valid format", "email cannot be blank"] }
```## initialize() [](#method-i-initialize)
Initialize a new error collection.

**@return** [Errors] a new instance of Errors

## to_h() [](#method-i-to_h)
Convert errors to a hash format with arrays of messages.

**@return** [Hash{Symbol => Array<String>}] Hash with attribute keys and message arrays


**@example**
```ruby
errors.to_h # => { email: ["must be valid format", "cannot be blank"] }
```## to_hash(fullfalse) [](#method-i-to_hash)
Convert errors to a hash format with optional full messages.

**@param** [Boolean] Whether to include full messages with attribute names

**@return** [Hash{Symbol => Array<String>}] Hash with attribute keys and message arrays


**@example**
```ruby
errors.to_hash # => { email: ["must be valid format", "cannot be blank"] }
errors.to_hash(true) # => { email: ["email must be valid format", "email cannot be blank"] }
```## to_s() [](#method-i-to_s)
Convert errors to a human-readable string format.

**@return** [String] Formatted error messages joined with periods


**@example**
```ruby
errors.to_s # => "email must be valid format. email cannot be blank"
```