# Basics - Setup

Tasks are the core building blocks of CMDx, encapsulating business logic within structured, reusable objects. Each task represents a unit of work with automatic attribute validation, error handling, and execution tracking.

## Table of Contents

- [Structure](#structure)
- [Inheritance](#inheritance)
- [Lifecycle](#lifecycle)

## Structure

Tasks inherit from `CMDx::Task` and require only a `work` method:

```ruby
class ValidateDocument < CMDx::Task
  def work
    # Your logic here...
  end
end
```

An exception will be raised if a work method is not defined.

```ruby
class IncompleteTask < CMDx::Task
  # No `work` method defined
end

IncompleteTask.execute #=> raises CMDx::UndefinedMethodError
```

## Inheritance

All configuration options are inheritable by any child classes.
Create a base class to share common configuration across tasks:

```ruby
class ApplicationTask < CMDx::Task
  register :middleware, SecurityMiddleware

  before_execution :initialize_request_tracking

  attribute :session_id

  private

  def initialize_request_tracking
    context.tracking_id ||= SecureRandom.uuid
  end
end

class SyncInventory < ApplicationTask
  def work
    # Your logic here...
  end
end
```

## Lifecycle

Tasks follow a predictable call pattern with specific states and statuses:

> [!CAUTION]
> Tasks are single-use objects. Once executed, they are frozen and cannot be executed again.

| Stage | State | Status | Description |
|-------|-------|--------|-------------|
| **Instantiation** | `initialized` | `success` | Task created with context |
| **Validation** | `executing` | `success`/`failed` | Attributes validated |
| **Execution** | `executing` | `success`/`failed`/`skipped` | `work` method runs |
| **Completion** | `executed` | `success`/`failed`/`skipped` | Result finalized |
| **Freezing** | `executed` | `success`/`failed`/`skipped` | Task becomes immutable |

---

- **Prev:** [Getting Started](../getting_started.md)
- **Next:** [Basics - Execution](execution.md)
