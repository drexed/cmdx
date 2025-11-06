# Module: CMDx::Coercions::Date
  
**Extended by:** CMDx::Coercions::Date
    

Converts various input types to Date format

Handles conversion from strings, Date objects, DateTime objects, Time objects,
and other date-like values to Date objects using Ruby's built-in parsing
capabilities and optional custom format parsing.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a Date object
**@option** [] 

**@param** [Object] The value to convert to a Date

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to a Date

**@return** [Date] The converted Date object


**@example**
```ruby
Date.call("2023-12-25")           # => #<Date: 2023-12-25>
Date.call("Dec 25, 2023")        # => #<Date: 2023-12-25>
```
**@example**
```ruby
Date.call("25/12/2023", strptime: "%d/%m/%Y")  # => #<Date: 2023-12-25>
Date.call("12-25-2023", strptime: "%m-%d-%Y")  # => #<Date: 2023-12-25>
```
**@example**
```ruby
Date.call(Date.new(2023, 12, 25)) # => #<Date: 2023-12-25>
Date.call(DateTime.new(2023, 12, 25)) # => #<Date: 2023-12-25>
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a Date object

**@option** [] 

**@param** [Object] The value to convert to a Date

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to a Date

**@return** [Date] The converted Date object


**@example**
```ruby
Date.call("2023-12-25")           # => #<Date: 2023-12-25>
Date.call("Dec 25, 2023")        # => #<Date: 2023-12-25>
```
**@example**
```ruby
Date.call("25/12/2023", strptime: "%d/%m/%Y")  # => #<Date: 2023-12-25>
Date.call("12-25-2023", strptime: "%m-%d-%Y")  # => #<Date: 2023-12-25>
```
**@example**
```ruby
Date.call(Date.new(2023, 12, 25)) # => #<Date: 2023-12-25>
Date.call(DateTime.new(2023, 12, 25)) # => #<Date: 2023-12-25>
```