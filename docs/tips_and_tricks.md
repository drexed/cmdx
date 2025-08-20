# Tips and Tricks

This guide covers advanced patterns and optimization techniques for getting the most out of CMDx in production applications.

## Table of Contents

TODO: add a style guide suggestion

- [Project Organization](#project-organization)
  - [Directory Structure](#directory-structure)
  - [Naming Conventions](#naming-conventions)
- [Attribute Options](#attribute-options)
- [ActiveRecord Query Tagging](#activerecord-query-tagging)

## Project Organization

### Directory Structure

Create a well-organized command structure for maintainable applications:

```txt
/app
  /tasks
    /orders
      - charge_order.rb
      - validate_order.rb
      - fulfill_order.rb
      - process_order.rb # workflow
    /notifications
      - send_email.rb
      - send_sms.rb
      - post_slack_message.rb
      - deliver_notifications.rb # workflow
    - application_task.rb # base class
    - login_user.rb
    - register_user.rb
```

### Naming Conventions

Follow consistent naming patterns for clarity and maintainability:

```ruby
# Verb + Noun
class ProcessOrder < CMDx::Task; end
class SendEmail < CMDx::Task; end
class ValidatePayment < CMDx::Task; end

# Use present tense verbs for actions
class CreateUser < CMDx::Task; end      # ✓ Good
class CreatingUser < CMDx::Task; end    # ❌ Avoid
class UserCreation < CMDx::Task; end    # ❌ Avoid
```

## Attribute Options

Use Rails `with_options` to reduce duplication and improve readability:

```ruby
class UpdateUserProfile < CMDx::Task
  # Apply common options to multiple attributes
  with_options(type: :string, presence: true) do
    attributes :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    required :first_name, :last_name
    optional :phone, format: { with: /\A\+?[\d\s\-\(\)]+\z/ }
  end

  # Nested attributes with shared prefix
  required :address do
    with_options(prefix: :address_) do
      attributes :street, :city, :postal_code, type: :string
      required :country, type: :string, inclusion: { in: VALID_COUNTRIES }
      optional :state, type: :string
    end
  end

  def work
    # Your logic here...
  end
end
```

## ActiveRecord Query Tagging

Automatically tag SQL queries for better debugging:

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags << :cmdx_task_class
config.active_record.query_log_tags << :cmdx_chain_id

# app/tasks/application_task.rb
class ApplicationTask < CMDx::Task
  before_execution :set_execution_context

  private

  def set_execution_context
    # NOTE: This could easily be made into a middleware
    ActiveSupport::ExecutionContext.set(
      cmdx_task_class: self.class.name,
      cmdx_chain_id: chain.id
    )
  end
end

# SQL queries will now include comments like:
# /*cmdx_task_class:ProcessOrderTask,cmdx_chain_id:018c2b95-b764-7615*/ SELECT * FROM orders WHERE id = 1
```

---

- **Prev:** [AI Prompts](ai_prompts.md)
- **Next:** [Getting Started](getting_started.md)
