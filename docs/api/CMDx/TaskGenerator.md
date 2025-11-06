# Class: Cmdx::TaskGenerator
**Inherits:** Rails::Generators::NamedBase
    

Generates CMDx task files for Rails applications

This generator creates task classes that inherit from either ApplicationTask
(if defined) or CMDx::Task. It generates the task file in the standard Rails
tasks directory structure.



# Instance Methods
## copy_files() [](#method-i-copy_files)
Copies the task template to the Rails application

Creates a new task file at `[app/tasks/](class_path)/[file_name].rb` using the
task template. The file is placed in the standard Rails tasks directory
structure, maintaining proper namespacing if the task is nested.

**@return** [void] 


**@example**
```ruby
rails generate cmdx:task UserRegistration
# => Creates app/tasks/user_registration.rb
```
**@example**
```ruby
rails generate cmdx:task Admin::UserManagement
# => Creates app/tasks/admin/user_management.rb
```