# Module: CMDx::Coercions::Time
  
**Extended by:** CMDx::Coercions::Time
    

Converts various input types to Time format

Handles conversion from strings, dates, and other time-like objects to Time
using Ruby's built-in time parsing methods. Supports custom strptime formats
and raises CoercionError for values that cannot be converted to Time.


# Class Methods
## call(value , options {}) [](#method-c-call)
Converts a value to a Time object
**@option** [] 

**@param** [Object] The value to convert to a Time object

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to a Time object

**@return** [Time] The converted Time object


**@example**
```ruby
Time.call(Time.now)                    # => Time object (unchanged)
Time.call(DateTime.now)                # => Time object (converted)
Time.call(Date.today)                  # => Time object (converted)
```
**@example**
```ruby
Time.call("2023-12-25 10:30:00")      # => Time object
Time.call("2023-12-25")               # => Time object
Time.call("10:30:00")                 # => Time object
```
**@example**
```ruby
Time.call("25/12/2023", strptime: "%d/%m/%Y")  # => Time object
Time.call("12-25-2023", strptime: "%m-%d-%Y")  # => Time object
```
# Instance Methods
## call(value, options{}) [](#method-i-call)
Converts a value to a Time object

**@option** [] 

**@param** [Object] The value to convert to a Time object

**@param** [Hash] Optional configuration parameters

**@raise** [CoercionError] If the value cannot be converted to a Time object

**@return** [Time] The converted Time object


**@example**
```ruby
Time.call(Time.now)                    # => Time object (unchanged)
Time.call(DateTime.now)                # => Time object (converted)
Time.call(Date.today)                  # => Time object (converted)
```
**@example**
```ruby
Time.call("2023-12-25 10:30:00")      # => Time object
Time.call("2023-12-25")               # => Time object
Time.call("10:30:00")                 # => Time object
```
**@example**
```ruby
Time.call("25/12/2023", strptime: "%d/%m/%Y")  # => Time object
Time.call("12-25-2023", strptime: "%m-%d-%Y")  # => Time object
```