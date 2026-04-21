# Logging

CMDx logs every task execution at `INFO` with the full `Result#to_h` payload, giving you a structured event stream for free. Pick a formatter that matches your logging infrastructure.

## Formatters

| Formatter | Use Case | Output Style |
|-----------|----------|--------------|
| `Line` | Traditional logging (default) | Single-line `Logger::Formatter` style |
| `JSON` | Structured systems | Compact JSON, one object per line |
| `KeyValue` | Log parsing | `key=value.inspect` pairs |
| `Logstash` | ELK stack | JSON with `@version` / `@timestamp` |
| `Raw` | Minimal output | Message body only (no severity/timestamp) |

!!! note

    The class name is `CMDx::LogFormatters::JSON` (uppercase). The other formatter classes use CamelCase: `Line`, `KeyValue`, `Logstash`, `Raw`.

=== "Line (default)"

    ```log
    I, [2026-04-19T10:30:45.123456Z #12345] INFO -- cmdx: cid="..." index=0 ... state="complete" status="success" ...
    ```

=== "JSON"

    ```json
    {"severity":"INFO","timestamp":"2026-04-19T10:30:45.123456Z","progname":"cmdx","pid":12345,"message":{"cid":"...","index":0,"root":true,"type":"Task","task":"MyTask","tid":"...","state":"complete","status":"success","reason":null,"metadata":{},"strict":false,"deprecated":false,"retried":false,"retries":0,"duration":12.34,"tags":[]}}
    ```

=== "KeyValue"

    ```log
    severity="INFO" timestamp="2026-04-19T10:30:45.123456Z" progname="cmdx" pid=12345 message={cid: "...", index: 0, ...}
    ```

=== "Logstash"

    ```json
    {"severity":"INFO","progname":"cmdx","pid":12345,"message":{...},"@version":"1","@timestamp":"2026-04-19T10:30:45.123456Z"}
    ```

=== "Raw"

    ```log
    cid="..." index=0 root=true type="Task" task=MyTask tid="..." state="complete" status="success" ...
    ```

## Sample Lifecycle

A single chain emitting a successful task, a skipped task, a failed leaf, and the workflow that propagated the failure:

```log
# Success
I, [2026-04-19T17:04:07.292614Z #20108] INFO -- cmdx: cid="019b4c2b-087b-79be-8ef2-96c11b659df5" index=0 root=true type="Task" task=GenerateInvoice tid="019b4c2b-0878-704d-ba0b-daa5410123ec" context=#<CMDx::Context ...> state="complete" status="success" reason=nil metadata={} strict=false deprecated=false retried=false retries=0 duration=12.34 tags=[]

# Skipped
I, [2026-04-19T17:04:11.496881Z #20139] INFO -- cmdx: cid="019b4c2b-18e8-7af6-a38b-63b042c4fbed" index=0 root=true type="Task" task=ValidateCustomer tid="019b4c2b-18e5-7230-af7e-5b4a4bd7cda2" context=#<CMDx::Context ...> state="interrupted" status="skipped" reason="Customer already validated" metadata={} strict=false deprecated=false retried=false retries=0 duration=2.18 tags=[]

# Failed (root cause via fail!)
I, [2026-04-19T17:04:15.875306Z #20173] INFO -- cmdx: cid="019b4c2b-2a02-7dbc-b713-b20a7379704f" index=1 root=false type="Task" task=CalculateTax tid="019b4c2b-2a00-70b7-9fab-2f14db9139ef" context=#<CMDx::Context ...> state="interrupted" status="failed" reason="tax service unavailable" metadata={error_code: "TAX_SERVICE_UNAVAILABLE"} strict=false deprecated=false retried=false retries=0 duration=8.92 tags=[] cause=nil origin=nil threw_failure=<CalculateTax 019b4c2b-2a00-...> caused_failure=<CalculateTax 019b4c2b-2a00-...> rolled_back=false

# Failed workflow that propagated the above failure
I, [2026-04-19T17:04:15.876012Z #20173] INFO -- cmdx: cid="019b4c2b-2a02-7dbc-b713-b20a7379704f" index=0 root=true type="Workflow" task=BillingWorkflow tid="019b4c2b-3de6-70b9-9c16-5be13b1a463c" ... state="interrupted" status="failed" reason="tax service unavailable" cause=nil origin=<CalculateTax 019b4c2b-2a00-...> threw_failure=<CalculateTax 019b4c2b-2a00-...> caused_failure=<CalculateTax 019b4c2b-2a00-...> rolled_back=false
```

!!! tip

    Use logging as a low-level event stream to track every task in a request. Pair `cid` with your APM's correlation field for distributed tracing.

!!! note

    A rescued `StandardError` (not a `fail!` call) sets `cause=#<TheError: …>` and rewrites `reason` to `"[TheError] message"` with empty metadata.

## Structure

Every log entry is built from `Result#to_h`. Available fields:

### Severity / Time (added by formatter)

| Field | Description | Example |
|-------|-------------|---------|
| `severity` | Logger level name | `INFO`, `WARN`, `ERROR` |
| `timestamp` | UTC ISO 8601 with microseconds | `2026-04-19T18:43:15.000000Z` |
| `pid` | Process ID | `3784` |
| `progname` | Logger progname | `cmdx` (default) |

`Raw` is the exception — it emits only the `message` body.

### Identity

| Field | Description | Example |
|-------|-------------|---------|
| `cid` | Chain UUID (uuid_v7) | `"018c2b95-b764-7615-..."` |
| `index` | Position in chain (root is 0) | `0`, `1`, `2` |
| `root` | `true` for the root task's result | `true`, `false` |
| `type` | `"Task"` or `"Workflow"` | `"Task"` |
| `task` | Task class | `GenerateInvoice` |
| `tid` | Task UUID (uuid_v7) | `"018c2b95-..."` |
| `context` | Frozen `CMDx::Context` (root teardown) | `#<CMDx::Context ...>` |
| `tags` | Tags from `settings(tags: [...])` | `["billing"]` |

### Outcome

| Field | Description | Example |
|-------|-------------|---------|
| `state` | Lifecycle state | `"complete"`, `"interrupted"` |
| `status` | Business outcome | `"success"`, `"skipped"`, `"failed"` |
| `reason` | String passed to halt method | `"payment declined"` or `nil` |
| `metadata` | Hash passed to halt method | `{ code: "INSUFFICIENT_FUNDS" }` |

### Lifecycle

| Field | Description | Example |
|-------|-------------|---------|
| `strict` | `true` when produced via `execute!` | `false` |
| `deprecated` | `true` when the task class is deprecated | `false` |
| `retried` | `true` when at least one retry happened | `false` |
| `retries` | Number of retry attempts performed | `0` |
| `duration` | Lifecycle duration in milliseconds | `12.34` |

### Failure-only fields

These are present **only** when `status == "failed"`:

| Field | Description |
|-------|-------------|
| `cause` | Underlying exception (or `nil` for `fail!`) |
| `origin` | `{ task:, tid: }` of the upstream `Result` this failure was echoed from, or `nil` for a locally originated failure |
| `threw_failure` | `{ task:, tid: }` of the nearest upstream failed result, or this result |
| `caused_failure` | `{ task:, tid: }` of the originating failed result, or this result |
| `rolled_back` | `true` when the task's `#rollback` ran |

## Configuration

Configure the formatter and level globally or per-task:

=== "Global"

    ```ruby
    CMDx.configure do |config|
      config.log_formatter = CMDx::LogFormatters::JSON.new
      config.log_level     = Logger::DEBUG
      config.logger        = Logger.new($stdout, progname: "cmdx")
    end
    ```

=== "Per-task"

    ```ruby
    class ProcessSubscription < CMDx::Task
      settings(
        log_formatter: CMDx::LogFormatters::JSON.new,
        log_level: Logger::DEBUG
      )
    end
    ```

!!! note

    When a task overrides `:log_level` or `:log_formatter`, `LoggerProxy` `dup`s the global logger so settings don't leak across sibling tasks.

### Custom Logger

Swap the underlying `Logger` instance per task to route lifecycle entries to a different sink (separate file, syslog, structured-log gem, etc.):

```ruby
class AuditTransfer < CMDx::Task
  settings(
    logger: Logger.new(Rails.root.join("log/audit.log"), progname: "audit"),
    log_formatter: CMDx::LogFormatters::JSON.new
  )
end
```

The given logger is used as-is — `LoggerProxy` only `dup`s it when `:log_level` or `:log_formatter` differ from what the logger already has set.

### Silencing a Task

Raise the per-task level above `INFO` to suppress the lifecycle log line:

```ruby
class QuietTask < CMDx::Task
  settings(log_level: Logger::WARN)
end
```

## Log Levels

CMDx logs each task result at `INFO` once the lifecycle completes. The framework itself emits no `WARN` or `ERROR` lines — use callbacks (`on_failed`, `on_skipped`) or telemetry subscribers (`:task_retried`, `:task_executed`) to log at higher severities.

```ruby
class VerboseTask < CMDx::Task
  settings(log_level: Logger::DEBUG)

  def work
    logger.debug { "feature flags: #{Features.active_flags.inspect}" }
    # ...
  end
end
```

!!! note

    Strict-mode failures (`execute!`) still produce the lifecycle log line and the `:task_executed` telemetry event — `Runtime` finalizes the result *before* re-raising the `Fault`.

## Usage Inside Work

`Task#logger` returns the per-task `Logger` (with the task's overrides applied):

```ruby
class ProcessSubscription < CMDx::Task
  def work
    logger.debug { "subscriber: #{context.subscriber_id}" }
    logger.info  { "starting subscription processing" }
  end
end
```
