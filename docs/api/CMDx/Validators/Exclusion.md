# Module: CMDx::Validators::Exclusion
  
**Extended by:** CMDx::Validators::Exclusion
    

Validates that a value is not included in a specified set or range

This validator ensures that the given value is excluded from a collection of
forbidden values or falls outside a specified range. It supports both discrete
value lists and range-based exclusions.


# Class Methods
## call(value , options {}) [](#method-c-call)
Validates that a value is excluded from the specified options
**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The value to validate for exclusion

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value is found in the forbidden collection


**@example**
```ruby
Exclusion.call("admin", in: ["admin", "root", "superuser"])
# => raises ValidationError if value is "admin"
```
**@example**
```ruby
Exclusion.call(5, in: 1..10)
# => raises ValidationError if value is 5 (within 1..10)
```
**@example**
```ruby
Exclusion.call("test", in: ["test", "demo"], message: "value %{values} is forbidden")
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Validates that a value is excluded from the specified options

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The value to validate for exclusion

**@param** [Hash] Validation configuration options

**@raise** [ValidationError] When the value is found in the forbidden collection


**@example**
```ruby
Exclusion.call("admin", in: ["admin", "root", "superuser"])
# => raises ValidationError if value is "admin"
```
**@example**
```ruby
Exclusion.call(5, in: 1..10)
# => raises ValidationError if value is 5 (within 1..10)
```
**@example**
```ruby
Exclusion.call("test", in: ["test", "demo"], message: "value %{values} is forbidden")
```