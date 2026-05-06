# Logging

Every time a task finishes its lifecycle, CMDx logs **once** at `INFO` with the full `Result#to_h` payload. Think of it as a structured trail you can ship to Splunk, Datadog, ELK, or plain files—pick a formatter that matches how your team searches logs.

## Formatters

| Formatter  | Good when you want…         | Output style                                    |
| ---------- | --------------------------- | ----------------------------------------------- |
| `Line`     | Classic log lines (default) | Single-line `Logger::Formatter` style           |
| `JSON`     | Pipelines that eat JSON     | One compact JSON object per line                |
| `KeyValue` | Grepping `key=value`        | `key=value.inspect` pairs                       |
| `Logstash` | ELK-style stacks            | JSON with `@version` / `@timestamp`             |
| `Raw`      | Bare payload                | Message body only—no severity/timestamp wrapper |

Note

The JSON class is `CMDx::LogFormatters::JSON` (JSON in caps). The others are CamelCase: `Line`, `KeyValue`, `Logstash`, `Raw`.

```text
I, [2026-04-19T10:30:45.123456Z #12345] INFO -- cmdx: cid="..." index=0 ... state="complete" status="success" ...
```

```json
{"severity":"INFO","timestamp":"2026-04-19T10:30:45.123456Z","progname":"cmdx","pid":12345,"message":{"cid":"...","index":0,"root":true,"type":"Task","task":"MyTask","tid":"...","state":"complete","status":"success","reason":null,"metadata":{},"strict":false,"deprecated":false,"retried":false,"retries":0,"duration":12.34,"tags":[]}}
```

```text
severity="INFO" timestamp="2026-04-19T10:30:45.123456Z" progname="cmdx" pid=12345 message={cid: "...", index: 0, ...}
```

```json
{"severity":"INFO","progname":"cmdx","pid":12345,"message":{...},"@version":"1","@timestamp":"2026-04-19T10:30:45.123456Z"}
```

```text
cid="..." index=0 root=true type="Task" task=MyTask tid="..." state="complete" status="success" ...
```

## Sample lifecycle

Here’s a real-ish line: a leaf task failed and propagation fields show how the failure relates to the chain:

```text
I, [2026-04-19T17:04:15.875306Z #20173] INFO -- cmdx: cid="019b4c2b-2a02-..." index=1 root=false type="Task" task=CalculateTax tid="019b4c2b-2a00-..." state="interrupted" status="failed" reason="tax service unavailable" metadata={error_code: "TAX_SERVICE_UNAVAILABLE"} duration=8.92 cause=nil origin=nil threw_failure=<CalculateTax ...> caused_failure=<CalculateTax ...> rolled_back=false
```

Tip

**`cid`** is your friend for tracing: pair it with your APM’s correlation id. To thread an external request id through, set a `correlation_id` resolver and filter on **`xid`**—see [Configuration – correlation id](https://drexed.github.io/cmdx/configuration/#correlation-id-xid). If Ruby rescues a plain `StandardError` (not `fail!`), you’ll see `cause=#<TheError: …>` and `reason` becomes `"[TheError] message"`.

## What’s in the log?

Each line is built from `Result#to_h`. Fields fall into a few buckets:

### Severity / time (formatter adds these)

| Field       | What it is                  | Example                        |
| ----------- | --------------------------- | ------------------------------ |
| `severity`  | Log level name              | `INFO`, `WARN`, `ERROR`        |
| `timestamp` | UTC, ISO 8601, microseconds | `2026-04-19T18:43:15.000000Z`  |
| `pid`       | OS process id               | `3784`                         |
| `progname`  | Logger progname             | `cmdx` (unless you changed it) |

`Raw` skips the wrapper and prints only the message body.

### Identity

| Field     | What it is                                                                                  | Example                    |
| --------- | ------------------------------------------------------------------------------------------- | -------------------------- |
| `cid`     | Chain id (uuid_v7)                                                                          | `"018c2b95-b764-7615-..."` |
| `xid`     | External correlation (e.g. Rails `request_id`); `nil` unless you configure `correlation_id` | `"req-abc-123"`            |
| `index`   | Step in the chain (root = 0)                                                                | `0`, `1`, `2`              |
| `root`    | Is this the root task’s result?                                                             | `true` / `false`           |
| `type`    | `"Task"` or `"Workflow"`                                                                    | `"Task"`                   |
| `task`    | Task class name                                                                             | `GenerateInvoice`          |
| `tid`     | This task run’s id (uuid_v7)                                                                | `"018c2b95-..."`           |
| `context` | Frozen `CMDx::Context` (root teardown)                                                      | `#<CMDx::Context ...>`     |
| `tags`    | From `settings(tags: [...])`                                                                | `["billing"]`              |

### Outcome

| Field      | What it is                 | Example                              |
| ---------- | -------------------------- | ------------------------------------ |
| `state`    | Where the lifecycle ended  | `"complete"`, `"interrupted"`        |
| `status`   | Business result            | `"success"`, `"skipped"`, `"failed"` |
| `reason`   | String from `fail!` / halt | `"payment declined"` or `nil`        |
| `metadata` | Hash from halt             | `{ code: "INSUFFICIENT_FUNDS" }`     |

### Lifecycle extras

| Field        | What it is                | Example |
| ------------ | ------------------------- | ------- |
| `strict`     | Ran via `execute!`?       | `false` |
| `deprecated` | Task class is deprecated? | `false` |
| `retried`    | At least one retry?       | `false` |
| `retries`    | How many retries          | `0`     |
| `duration`   | Milliseconds              | `12.34` |

### Only when `status == "failed"`

| Field            | Meaning                                                                              |
| ---------------- | ------------------------------------------------------------------------------------ |
| `cause`          | Underlying exception, or `nil` for `fail!`                                           |
| `origin`         | `{ task:, tid: }` if this failure was echoed from upstream; `nil` if it started here |
| `threw_failure`  | `{ task:, tid: }` of the nearest upstream failure                                    |
| `caused_failure` | `{ task:, tid: }` of the failure that actually caused the chain to fail              |
| `rolled_back`    | `true` if `#rollback` ran                                                            |

## Configuration

Set formatter, level, and logger on `CMDx.configure`, or override per task with `settings(...)`. Full list: [Configuration – logging](https://drexed.github.io/cmdx/configuration/index.md).

Note

If a task tweaks `:log_level` or `:log_formatter`, `LoggerProxy` **dup**s the global logger so siblings don’t accidentally inherit those tweaks.

### Custom logger

Point one task at its own `Logger`—different file, syslog, fancy structured gem, whatever:

```ruby
class AuditTransfer < CMDx::Task
  settings(
    logger: Logger.new(Rails.root.join("log/audit.log"), progname: "audit"),
    log_formatter: CMDx::LogFormatters::JSON.new
  )
end
```

CMDx uses that logger as-is; it only dup’s when level or formatter differ from what you passed.

### Silence the lifecycle line

Bump the task’s log level above `INFO` so the automatic completion line doesn’t fire:

```ruby
class QuietTask < CMDx::Task
  settings(log_level: Logger::WARN)
end
```

### Drop fields from the log (not from the result)

`log_exclusions` strips **top-level** keys from the logged hash—handy for huge `:context` or sensitive `:metadata` while keeping them on the `Result` and telemetry.

```ruby
CMDx.configure do |config|
  config.log_exclusions = [:context, :metadata]
end

class ImportPayroll < CMDx::Task
  settings(log_exclusions: [:context])
end
```

Only top-level keys; no nested paths. Default is empty = log everything.

## Log levels

CMDx writes the lifecycle line at **`INFO`** when the run completes. The framework itself doesn’t spam `WARN` / `ERROR` for you—use callbacks (`on_failed`, `on_skipped`) or telemetry (`:task_retried`, `:task_executed`) if you want louder logs.

```ruby
class VerboseTask < CMDx::Task
  settings(log_level: Logger::DEBUG)

  def work
    logger.debug { "feature flags: #{Features.active_flags.inspect}" }
    # ...
  end
end
```

Note

**`execute!`** still logs the lifecycle line and still emits `:task_executed`—Runtime finishes the result **before** it re-raises the `Fault`.

## Logging inside `work`

`Task#logger` is the per-task logger (respects your settings):

```ruby
class ProcessSubscription < CMDx::Task
  def work
    logger.debug { "subscriber: #{context.subscriber_id}" }
    logger.info  { "starting subscription processing" }
  end
end
```
