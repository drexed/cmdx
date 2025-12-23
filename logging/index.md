# Logging

CMDx automatically logs every task execution with structured data, making debugging and monitoring effortless. Choose from multiple formatters to match your logging infrastructure.

## Formatters

Choose the format that works best for your logging system:

| Formatter  | Use Case            | Output Style                  |
| ---------- | ------------------- | ----------------------------- |
| `Line`     | Traditional logging | Single-line format            |
| `Json`     | Structured systems  | Compact JSON                  |
| `KeyValue` | Log parsing         | `key=value` pairs             |
| `Logstash` | ELK stack           | JSON with @version/@timestamp |
| `Raw`      | Minimal output      | Message content only          |

Sample output:

```text
<!-- Success (INFO level) -->
I, [2025-12-23T17:04:07.292614Z #20108] INFO -- cmdx: {index: 1, chain_id: "019b4c2b-087b-79be-8ef2-96c11b659df5", type: "Task", tags: [], class: "GenerateInvoice", dry_run: false, id: "019b4c2b-0878-704d-ba0b-daa5410123ec", state: "complete", status: "success", outcome: "success", metadata: {runtime: 187}}

<!-- Skipped (INFO level) -->
I, [2025-12-23T17:04:11.496881Z #20139] INFO -- cmdx: {index: 2, chain_id: "019b4c2b-18e8-7af6-a38b-63b042c4fbed", type: "Task", tags: [], class: "ValidateCustomer", dry_run: false, id: "019b4c2b-18e5-7230-af7e-5b4a4bd7cda2", state: "interrupted", status: "skipped", outcome: "skipped", metadata: {}, reason: "Customer already validated", cause: #<CMDx::SkipFault: Customer already validated>, rolled_back: false}

<!-- Failed (INFO level) -->
I, [2025-12-23T17:04:15.875306Z #20173] INFO -- cmdx: {index: 3, chain_id: "019b4c2b-2a02-7dbc-b713-b20a7379704f", type: "Task", tags: [], class: "CalculateTax", dry_run: false, id: "019b4c2b-2a00-70b7-9fab-2f14db9139ef", state: "interrupted", status: "failed", outcome: "failed", metadata: {error_code: "TAX_SERVICE_UNAVAILABLE"}, reason: "Validation failed", cause: #<CMDx::FailFault: Validation failed>, rolled_back: false}

<!-- Failed Chain -->
I, [2025-12-23T17:04:20.972539Z #20209] INFO -- cmdx: {index: 0, chain_id: "019b4c2b-3de9-71f7-bcc3-2a98836bcfd7", type: "Workflow", tags: [], class: "BillingWorkflow", dry_run: false, id: "019b4c2b-3de6-70b9-9c16-5be13b1a463c", state: "interrupted", status: "failed", outcome: "interrupted", metadata: {}, reason: "Validation failed", cause: #<CMDx::FailFault: Validation failed>, rolled_back: false, threw_failure: {index: 3, chain_id: "019b4c2b-3de9-71f7-bcc3-2a98836bcfd7", type: "Task", tags: [], class: "CalculateTax", id: "019b4c2b-3dec-70b3-969b-c5b7896e3b27", state: "interrupted", status: "failed", outcome: "failed", metadata: {error_code: "TAX_SERVICE_UNAVAILABLE"}, reason: "Validation failed", cause: #<CMDx::FailFault: Validation failed>, rolled_back: false}, caused_failure: {index: 3, chain_id: "019b4c2b-3de9-71f7-bcc3-2a98836bcfd7", type: "Task", tags: [], class: "CalculateTax", id: "019b4c2b-3dec-70b3-969b-c5b7896e3b27", state: "interrupted", status: "failed", outcome: "failed", metadata: {error_code: "TAX_SERVICE_UNAVAILABLE"}, reason: "Validation failed", cause: #<CMDx::FailFault: Validation failed>, rolled_back: false}}
```

Tip

Use logging as a low-level event stream to track all tasks in a request. Combine with correlation for powerful distributed tracing.

## Structure

Every log entry includes rich metadata. Available fields depend on execution context and outcome.

### Core Fields

| Field       | Description             | Example                      |
| ----------- | ----------------------- | ---------------------------- |
| `severity`  | Log level               | `INFO`, `WARN`, `ERROR`      |
| `timestamp` | ISO 8601 execution time | `2022-07-17T18:43:15.000000` |
| `pid`       | Process ID              | `3784`                       |

### Task Information

| Field      | Description                 | Example                    |
| ---------- | --------------------------- | -------------------------- |
| `index`    | Execution sequence position | `0`, `1`, `2`              |
| `chain_id` | Unique execution chain ID   | `018c2b95-b764-7615...`    |
| `type`     | Execution unit type         | `Task`, `Workflow`         |
| `class`    | Task class name             | `GenerateInvoiceTask`      |
| `id`       | Unique task instance ID     | `018c2b95-b764-7615...`    |
| `tags`     | Custom categorization       | `["billing", "financial"]` |

### Execution Data

| Field      | Description          | Example                          |
| ---------- | -------------------- | -------------------------------- |
| `state`    | Lifecycle state      | `complete`, `interrupted`        |
| `status`   | Business outcome     | `success`, `skipped`, `failed`   |
| `outcome`  | Final classification | `success`, `interrupted`         |
| `metadata` | Custom task data     | `{order_id: 123, amount: 99.99}` |

### Failure Chain

| Field            | Description                      |
| ---------------- | -------------------------------- |
| `reason`         | Reason given for the stoppage    |
| `caused`         | Cause exception details          |
| `caused_failure` | Original failing task details    |
| `threw_failure`  | Task that propagated the failure |

## Usage

Access the framework logger directly within tasks:

```ruby
class ProcessSubscription < CMDx::Task
  def work
    logger.debug { "Activated feature flags: #{Features.active_flags}" }
    # Your logic here...
    logger.info("Subscription processed")
  end
end
```
