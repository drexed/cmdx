# Logging

CMDx provides comprehensive automatic logging for task execution with structured data, customizable formatters, and intelligent severity mapping. All task results are logged after completion with rich metadata for debugging and monitoring.

## Table of Contents

- [Formatters](#formatters)
- [Structure](#structure)
- [Usage](#usage)

## Formatters

CMDx supports multiple log formatters to integrate with various logging systems:

| Formatter | Use Case | Output Style |
|-----------|----------|--------------|
| `Line` | Traditional logging | Single-line format |
| `Json` | Structured systems | Compact JSON |
| `KeyValue` | Log parsing | `key=value` pairs |
| `Logstash` | ELK stack | JSON with @version/@timestamp |
| `Raw` | Minimal output | Message content only |

Sample output:

```text
# Success (INFO level)
I, [2022-07-17T18:43:15.000000 #3784] INFO -- CreateOrder:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task"
class="CreateOrder" state="complete" status="success" metadata={runtime: 123}

# Skipped (WARN level)
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidatePayment:
index=1 state="interrupted" status="skipped" reason="Order already processed"

# Failed (ERROR level)
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- ProcessPayment:
index=2 state="interrupted" status="failed" metadata={error_code: "INSUFFICIENT_FUNDS"}

# Failed Chain
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- OrderWorkflow:
caused_failure={index: 2, class: "ProcessPayment", status: "failed"}
threw_failure={index: 1, class: "ValidatePayment", status: "failed"}
```

## Structure

All log entries include comprehensive execution metadata. Field availability depends on execution context and outcome.

### Core Fields

| Field | Description | Example |
|-------|-------------|---------|
| `severity` | Log level | `INFO`, `WARN`, `ERROR` |
| `timestamp` | ISO 8601 execution time | `2022-07-17T18:43:15.000000` |
| `pid` | Process ID | `3784` |

### Task Information

| Field | Description | Example |
|-------|-------------|---------|
| `index` | Execution sequence position | `0`, `1`, `2` |
| `chain_id` | Unique execution chain ID | `018c2b95-b764-7615...` |
| `type` | Execution unit type | `Task`, `Workflow` |
| `class` | Task class name | `ProcessOrderTask` |
| `id` | Unique task instance ID | `018c2b95-b764-7615...` |
| `tags` | Custom categorization | `["priority", "payment"]` |

### Execution Data

| Field | Description | Example |
|-------|-------------|---------|
| `state` | Lifecycle state | `complete`, `interrupted` |
| `status` | Business outcome | `success`, `skipped`, `failed` |
| `outcome` | Final classification | `success`, `interrupted` |
| `metadata` | Custom task data | `{order_id: 123, amount: 99.99}` |

### Failure Chain

| Field | Description |
|-------|-------------|
| `reason` | Reason given for the stoppage |
| `caused` | Cause exception details |
| `caused_failure` | Original failing task details |
| `threw_failure` | Task that propagated the failure |

## Usage

Tasks have access to the frameworks logger.

```ruby
class ProcessOrder < CMDx::Task
  def work
    logger.debug { "Activated feature flags: #{Features.active_flags}" }
    # Your logic here...
    logger.info("Order processed")
  end
end
```

---

- **Prev:** [Middlewares](middlewares.md)
- **Next:** [Internationalization (i18n)](internationalization.md)
