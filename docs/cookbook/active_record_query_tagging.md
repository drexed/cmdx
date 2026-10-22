# Active Record Query Tagging

Slow query in production? You want the log line to scream **which task** fired it — not “something in the app touched `reports`.”

Rails can append comment tags to every SQL statement. This recipe stamps each query with the task class, task id (`tid`), chain id (`cid`), and your correlation id (`xid`) for the duration of the task.

## What you'll see

```sql
/*application:MyApp,cmdx_task:ExportReport,cmdx_tid:018c2b95-b764-...,cmdx_cid:018c2b95-0878-...,cmdx_xid:req-9f1a*/ SELECT * FROM reports WHERE id = 1
```

That comment rides along in `pg_stat_statements`, RDS Performance Insights, and database logs — no per-query manual tagging.

## Setup

Turn on query log tags in Rails, then teach ExecutionContext what to publish.

```ruby
# config/application.rb

config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags += %i[cmdx_task cmdx_tid cmdx_cid cmdx_xid]
```

```ruby
class CmdxQueryTaggingMiddleware
  def call(task)
    chain = CMDx::Chain.current

    ActiveSupport::ExecutionContext.set(
      cmdx_task: task.class.name,
      cmdx_tid:  task.tid,
      cmdx_cid:  chain.id,
      cmdx_xid:  chain.xid
    ) { yield }
  end
end
```

## Usage

Point `correlation_id` at something you already have in requests (request id, trace parent, etc.), then register the middleware on your base task.

```ruby
class ApplicationTask < CMDx::Task
  settings correlation_id: -> { Current.request_id }

  register :middleware, CmdxQueryTaggingMiddleware.new
end
```

```ruby
class ExportReport < ApplicationTask
  required :report_id, coerce: :integer

  def work
    context.report = Report.includes(:line_items).find(report_id)
    context.csv    = ReportSerializer.new(context.report).to_csv
  end
end
```

## Notes

### End-to-end correlation

`cmdx_xid` is the chain's external correlation id (from `settings.correlation_id`). The same value can line up SQL comments, CMDx lifecycle logs, and your APM trace — one id to grep instead of three.
