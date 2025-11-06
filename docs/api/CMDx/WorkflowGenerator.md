# Class: Cmdx::WorkflowGenerator
**Inherits:** Rails::Generators::NamedBase
    

Generates CMDx workflow files for Rails applications

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
rails generate cmdx:workflow SendNotifications
# => Creates app/tasks/send_notifications.rb
```
**@example**
```ruby
rails generate cmdx:workflow Admin::SendNotifications
# => Creates app/tasks/admin/send_notifications.rb
```