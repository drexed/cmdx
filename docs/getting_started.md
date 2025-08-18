# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. Design robust workflows with automatic parameter validation, structured error handling, comprehensive logging, and intelligent execution flow control that scales from simple tasks to complex multi-step processes.

## Table of Contents

- [Installation](#installation)
- [Task Generator](#task-generator)

## Installation

Add CMDx to your Gemfile:

```ruby
gem 'cmdx'
```

For Rails applications, generate the configuration:

```bash
rails generate cmdx:install
```

> [!NOTE]
> This creates `config/initializers/cmdx.rb` with default settings. You can configure
> middlewares, logging, and other options globally in this file.

## Task Generator

Generate new CMDx tasks quickly using the built-in generator:

```bash
rails generate cmdx:task TaskName
```

This creates a new task file with the basic structure:

```ruby
# app/tasks/process_order.rb
class ProcessOrder < CMDx::Task
  def work
    # TODO: add logic here
  end
end
```

> [!TIP]
> Use **present tense verbs + noun** for task names, eg:
> `ProcessOrder`, `SendWelcomeEmail`, `ValidatePaymentDetails`

---
