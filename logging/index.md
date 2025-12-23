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
I, [2022-07-17T18:43:15.000000 #3784] INFO -- GenerateInvoice:
index=1 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="GenerateInvoice" state="complete" status="success" metadata={runtime: 187}

<!-- Skipped (WARN level) -->
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidateCustomer:
index=2 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="ValidateCustomer" state="interrupted" status="skipped" reason="Customer already validated"

<!-- Failed (ERROR level) -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- CalculateTax:
index=3 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="CalculateTax"  state="interrupted" status="failed" metadata={error_code: "TAX_SERVICE_UNAVAILABLE"}

<!-- Failed Chain -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- BillingWorkflow:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="BillingWorkflow"  state="interrupted" status="failed" caused_failure={index: 2, class: "CalculateTax", status: "failed"} threw_failure={index: 1, class: "ValidateCustomer", status: "failed"}
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
