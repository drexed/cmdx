# Class: CMDx::Attribute
**Inherits:** Object
    

Represents a configurable attribute within a CMDx task. Attributes define the
data structure and validation rules for task parameters. They can be nested to
create complex hierarchical data structures.


# Class Methods
## build(*names , **options ) [](#method-c-build)
Builds multiple attributes with the same configuration.
**@param** [Array<Symbol, String>] The names of the attributes to create

**@param** [Hash] Configuration options for the attributes

**@raise** [ArgumentError] When no names are provided or :as is used with multiple attributes

**@return** [Array<Attribute>] Array of created attributes

**@yield** [self] Block to configure nested attributes


**@example**
```ruby
Attribute.build(:first_name, :last_name, required: true, types: String)
```## optional(*names , **options ) [](#method-c-optional)
Creates optional attributes (not required).
**@param** [Array<Symbol, String>] The names of the attributes to create

**@param** [Hash] Configuration options for the attributes

**@return** [Array<Attribute>] Array of created optional attributes

**@yield** [self] Block to configure nested attributes


**@example**
```ruby
Attribute.optional(:description, :tags, types: String)
```## required(*names , **options ) [](#method-c-required)
Creates required attributes.
**@param** [Array<Symbol, String>] The names of the attributes to create

**@param** [Hash] Configuration options for the attributes

**@return** [Array<Attribute>] Array of created required attributes

**@yield** [self] Block to configure nested attributes


**@example**
```ruby
Attribute.required(:id, :name, types: [Integer, String])
```# Attributes
## children[RW] [](#attribute-i-children)
Returns the child attributes for nested structures.

**@return** [Array<Attribute>] Array of child attributes


**@example**
```ruby
attribute.children # => [#<Attribute @name=:street>, #<Attribute @name=:city>]
```## name[RW] [](#attribute-i-name)
Returns the name of this attribute.

**@return** [Symbol] The attribute name


**@example**
```ruby
attribute.name # => :user_id
```## options[RW] [](#attribute-i-options)
Returns the configuration options for this attribute.

**@return** [Hash{Symbol => Object}] Configuration options hash


**@example**
```ruby
attribute.options # => { required: true, default: 0 }
```## parent[RW] [](#attribute-i-parent)
Returns the parent attribute if this is a nested attribute.

**@return** [Attribute, nil] The parent attribute, or nil if root-level


**@example**
```ruby
attribute.parent # => #<Attribute @name=:address>
```## task[RW] [](#attribute-i-task)
Returns the task instance associated with this attribute.

**@return** [CMDx::Task] The task instance


**@example**
```ruby
attribute.task.context[:user_id] # => 42
```## types[RW] [](#attribute-i-types)
Returns the expected type(s) for this attribute's value.

**@return** [Array<Class>] Array of expected type classes


**@example**
```ruby
attribute.types # => [Integer, String]
```
# Instance Methods
## define_and_verify_tree() [](#method-i-define_and_verify_tree)
Defines and verifies the entire attribute tree including nested children.

## initialize(name, options{}) [](#method-i-initialize)
Creates a new attribute with the specified name and configuration.

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Symbol, String] The name of the attribute

**@param** [Hash] Configuration options for the attribute

**@return** [Attribute] a new instance of Attribute

**@yield** [self] Block to configure nested attributes


**@example**
```ruby
Attribute.new(:user_id, required: true, types: [Integer, String]) do
  required :name, types: String
  optional :email, types: String
end
```## method_name() [](#method-i-method_name)
Generates the method name for accessing this attribute.

**@return** [Symbol] The method name for the attribute


**@example**
```ruby
attribute.method_name # => :user_name
```## required?() [](#method-i-required?)
Checks if the attribute is required.

**@return** [Boolean] true if the attribute is required, false otherwise


**@example**
```ruby
attribute.required? # => true
```## source() [](#method-i-source)
Determines the source of the attribute value.

**@return** [Symbol] The source identifier for the attribute value


**@example**
```ruby
attribute.source # => :context
```