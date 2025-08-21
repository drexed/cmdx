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

```log
<!-- Success (INFO level) -->
I, [2022-07-17T18:43:15.000000 #3784] INFO -- GenerateInvoice:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task"
class="GenerateInvoice" state="complete" status="success" metadata={runtime: 187}

<!-- Skipped (WARN level) -->
W, [2022-07-17T18:43:15.000000 #3784] WARN -- ValidateCustomer:
index=1 state="interrupted" status="skipped" reason="Customer already validated"

<!-- Failed (ERROR level) -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- CalculateTax:
index=2 state="interrupted" status="failed" metadata={error_code: "TAX_SERVICE_UNAVAILABLE"}

<!-- Failed Chain -->
E, [2022-07-17T18:43:15.000000 #3784] ERROR -- BillingWorkflow:
caused_failure={index: 2, class: "CalculateTax", status: "failed"}
threw_failure={index: 1, class: "ValidateCustomer", status: "failed"}
```

> [!TIP]
> Logging can be used as low-level eventing system, ingesting all tasks performed within a small action or long running request. This ie where correlation is especially handy.

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
| `class` | Task class name | `GenerateInvoiceTask` |
| `id` | Unique task instance ID | `018c2b95-b764-7615...` |
| `tags` | Custom categorization | `["billing", "financial"]` |

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
class ProcessSubscription < CMDx::Task
  def work
    logger.debug { "Activated feature flags: #{Features.active_flags}" }
    # Your logic here...
    logger.info("Subscription processed")
  end
end
```

---

- **Prev:** [Middlewares](middlewares.md)
- **Next:** [Internationalization (i18n)](internationalization.md)
