# Module: CMDx::Deprecator
  
**Extended by:** CMDx::Deprecator
    

Handles deprecation warnings and restrictions for tasks.

The Deprecator module provides functionality to restrict usage of deprecated
tasks based on configuration settings. It supports different deprecation
behaviors including warnings, logging, and errors.


# Class Methods
## restrict(task ) [](#method-c-restrict)
Restricts task usage based on deprecation settings.
**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The task object to check for deprecation

**@param** [Hash] a customizable set of options

**@raise** [DeprecationError] When deprecation type is :raise or true

**@raise** [RuntimeError] When deprecation type is unknown


**@example**
```ruby
class MyTask
  settings(deprecate: :warn)
end

MyTask.new # => [MyTask] DEPRECATED: migrate to a replacement or discontinue use
```
# Instance Methods
## restrict(task) [](#method-i-restrict)
Restricts task usage based on deprecation settings.

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Object] The task object to check for deprecation

**@param** [Hash] a customizable set of options

**@raise** [DeprecationError] When deprecation type is :raise or true

**@raise** [RuntimeError] When deprecation type is unknown


**@example**
```ruby
class MyTask
  settings(deprecate: :warn)
end

MyTask.new # => [MyTask] DEPRECATED: migrate to a replacement or discontinue use
```