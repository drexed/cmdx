# Tips & Tricks

This guide covers advanced patterns and optimization techniques for getting the most out of CMDx in production applications.

## Table of Contents

- [Project Organization](#project-organization)
  - [Directory Structure](#directory-structure)
  - [Naming Conventions](#naming-conventions)
- [Advanced Configuration](#advanced-configuration)
  - [Environment-Specific Setup](#environment-specific-setup)
- [Parameter Optimization](#parameter-optimization)
  - [Efficient Parameter Definitions](#efficient-parameter-definitions)
- [Performance Optimization](#performance-optimization)
  - [Memory-Efficient Workflow Processing](#memory-efficient-workflow-processing)
- [Advanced Error Handling](#advanced-error-handling)
  - [Graceful Degradation](#graceful-degradation)
- [Monitoring and Observability](#monitoring-and-observability)
  - [ActiveRecord Query Tagging](#activerecord-query-tagging)

## Project Organization

### Directory Structure

Create a well-organized command structure for maintainable applications:

```txt
/app
  /commands
    /orders
      - process_order_task.rb
      - validate_order_task.rb
      - fulfill_order_task.rb
      - order_processing_workflow.rb
    /notifications
      - send_email_task.rb
      - send_sms_task.rb
      - post_slack_message_task.rb
      - notification_delivery_workflow.rb
    /payments
      - charge_payment_task.rb
      - refund_payment_task.rb
      - validate_payment_method_task.rb
    - application_task.rb
    - application_workflow.rb
```

### Naming Conventions

Follow consistent naming patterns for clarity and maintainability:

```ruby
# Tasks: Verb + Noun + Task
class ProcessOrderTask < CMDx::Task; end
class SendEmailTask < CMDx::Task; end
class ValidatePaymentTask < CMDx::Task; end

# Workflows: Noun + Verb + Workflow
class OrderProcessingWorkflow < CMDx::Workflow; end
class NotificationDeliveryWorkflow < CMDx::Workflow; end

# Use present tense verbs for actions
class CreateUserTask < CMDx::Task; end      # ✓ Good
class CreatingUserTask < CMDx::Task; end    # ❌ Avoid
class UserCreationTask < CMDx::Task; end    # ❌ Avoid
```

## Advanced Configuration

### Environment-Specific Setup

```ruby
# config/initializers/cmdx.rb
CMDx.configure do |config|
  case Rails.env
  when 'development'
    config.logger = Logger.new(STDOUT, formatter: CMDx::LogFormatters::PrettyLine.new)
    config.logger.level = Logger::DEBUG
  when 'test'
    config.logger = Logger.new("log/test.log", formatter: CMDx::LogFormatters::Line.new)
    config.logger.level = Logger::WARN
  when 'production'
    config.logger = Logger.new("log/cmdx.log", formatter: CMDx::LogFormatters::Logstash.new)
    config.logger.level = Logger::INFO
  end
end
```

## Parameter Optimization

### Efficient Parameter Definitions

Use Rails `with_options` to reduce duplication and improve readability:

```ruby
class UpdateUserProfileTask < CMDx::Task
  # Apply common options to multiple parameters
  with_options(type: :string, presence: true) do
    required :email, format: { with: URI::MailTo::EMAIL_REGEXP }
    optional :first_name, :last_name
    optional :phone, format: { with: /\A\+?[\d\s\-\(\)]+\z/ }
  end

  # Nested parameters with shared prefix
  required :address do
    with_options(prefix: :address_) do
      required :street, :city, :postal_code, type: :string
      required :country, type: :string, inclusion: { in: VALID_COUNTRIES }
      optional :state, type: :string
    end
  end

  # Shared validation rules
  with_options(type: :integer, numericality: { greater_than: 0 }) do
    optional :age, numericality: { less_than: 150 }
    optional :years_experience, numericality: { less_than: 80 }
  end

  def call
    # Implementation
  end
end
```

## Performance Optimization

### Memory-Efficient Workflow Processing

```ruby
class LargeDatasetProcessingWorkflow < CMDx::Workflow
  # Process in chunks to avoid memory issues
  process ProcessChunkDataTask, if: :has_more_data?
  process ProcessChunkTask
  process CleanupChunkTask
  process ProcessChunkDataTask, if: :has_more_data? # Repeat until done

  private

  def has_more_data?
    context.current_offset < context.total_records
  end
end

class ProcessChunkDataTask < CMDx::Task
  def call
    # Process data in small chunks
    chunk_size = 1000
    offset = context.current_offset || 0

    context.current_chunk = LargeDataset
      .limit(chunk_size)
      .offset(offset)
      .pluck(:id, :data)

    context.current_offset = offset + chunk_size

    # Skip if no more data
    skip!(reason: "No more data to process") if context.current_chunk.empty?
  end
end
```

## Advanced Error Handling

### Graceful Degradation

```ruby
class IntegrateServiceTask < CMDx::Task
  def call
    begin
      result = primary_service.call(context.data)
      context.service_result = result
    rescue Net::TimeoutError
      # Try backup service
      logger.warn "Primary service timeout, trying backup"
      context.service_result = backup_service.call(context.data)
      context.used_backup = true
    rescue StandardError => e
      # Log error but continue with degraded functionality
      logger.error "Service integration failed: #{e.message}"
      context.service_available = false
      # Task succeeds even without external service
    end
  end
end
```

## Monitoring and Observability

### ActiveRecord Query Tagging

Automatically tag SQL queries for better debugging:

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags << :cmdx_task_class
config.active_record.query_log_tags << :cmdx_chain_id

# app/commands/application_task.rb
class ApplicationTask < CMDx::Task
  before_execution :set_execution_context

  private

  def set_execution_context
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

- **Prev:** [Testing](testing.md)
- **Next:** [Getting Started](getting_started.md)
