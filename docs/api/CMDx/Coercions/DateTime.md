# Module: CMDx::Coercions::DateTime
  
**Extended by:** CMDx::Coercions::DateTime
    

Converts various input types to DateTime format

Handles conversion from date strings, Date objects, Time objects, and other
values that can be converted to DateTime using Ruby's DateTime.parse method or
custom strptime formats.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a DateTime
**@option** [] 

**@param** [Object] The value to convert to DateTime

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to DateTime

**@return** [DateTime] The converted DateTime value


**@example**
```ruby
DateTime.call("2023-12-25")               # => #<DateTime: 2023-12-25T00:00:00+00:00>
DateTime.call("Dec 25, 2023")             # => #<DateTime: 2023-12-25T00:00:00+00:00>
```
**@example**
```ruby
DateTime.call("25/12/2023", strptime: "%d/%m/%Y")
# => #<DateTime: 2023-12-25T00:00:00+00:00>
```
**@example**
```ruby
DateTime.call(Date.new(2023, 12, 25))     # => #<DateTime: 2023-12-25T00:00:00+00:00>
DateTime.call(Time.new(2023, 12, 25))     # => #<DateTime: 2023-12-25T00:00:00+00:00>
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a DateTime

**@option** [] 

**@param** [Object] The value to convert to DateTime

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to DateTime

**@return** [DateTime] The converted DateTime value


**@example**
```ruby
DateTime.call("2023-12-25")               # => #<DateTime: 2023-12-25T00:00:00+00:00>
DateTime.call("Dec 25, 2023")             # => #<DateTime: 2023-12-25T00:00:00+00:00>
```
**@example**
```ruby
DateTime.call("25/12/2023", strptime: "%d/%m/%Y")
# => #<DateTime: 2023-12-25T00:00:00+00:00>
```
**@example**
```ruby
DateTime.call(Date.new(2023, 12, 25))     # => #<DateTime: 2023-12-25T00:00:00+00:00>
DateTime.call(Time.new(2023, 12, 25))     # => #<DateTime: 2023-12-25T00:00:00+00:00>
```