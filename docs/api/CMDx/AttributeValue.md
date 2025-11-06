# Class: CMDx::AttributeValue
**Inherits:** Object
  
**Extended by:** Forwardable
    

Manages the value lifecycle for a single attribute within a task. Handles
value sourcing, derivation, coercion, and validation through a coordinated
pipeline that ensures data integrity and type safety.


# Attributes
## attribute[RW] [](#attribute-i-attribute)
Returns the attribute managed by this value handler.

**@return** [Attribute] The attribute instance


**@example**
```ruby
attr_value.attribute.name # => :user_id
```
# Instance Methods
## generate() [](#method-i-generate)
Generates the attribute value through the complete pipeline: sourcing,
derivation, coercion, and storage.

**@return** [Object, nil] The generated value or nil if generation failed


**@example**
```ruby
attr_value.generate # => 42
```## initialize(attribute) [](#method-i-initialize)
Creates a new attribute value manager for the given attribute.

**@param** [Attribute] The attribute to manage values for

**@return** [AttributeValue] a new instance of AttributeValue


**@example**
```ruby
attr = Attribute.new(:user_id, required: true)
attr_value = AttributeValue.new(attr)
```## validate() [](#method-i-validate)
Validates the current attribute value against configured validators.

**@raise** [ValidationError] When validation fails (handled internally)


**@example**
```ruby
attr_value.validate
# Validates value against :presence, :format, etc.
```## value() [](#method-i-value)
Retrieves the current value for this attribute from the task's attributes.

**@return** [Object, nil] The current attribute value or nil if not set


**@example**
```ruby
attr_value.value # => "john_doe"
```