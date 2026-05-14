# Active Record Query Tagging

Annotating every SQL statement with the task class and identifiers makes a slow query in `pg_stat_statements` or RDS Performance Insights immediately attributable to the code that issued it. The tag travels with the connection, so it shows up in the database log without per-query plumbing.

```sql
/*application:MyApp,cmdx_task:ExportReport,cmdx_tid:018c2b95-b764-...,cmdx_cid:018c2b95-0878-...,cmdx_xid:req-9f1a*/ SELECT * FROM reports WHERE id = 1
```

## Setup

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags += %i[cmdx_task cmdx_tid cmdx_cid cmdx_xid]
```

```ruby
# app/middlewares/cmdx_query_tagging_middleware.rb
# frozen_string_literal: true

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

```ruby
class ApplicationTask < CMDx::Task
  settings correlation_id: -> { Current.request_id }

  register :middleware, CmdxQueryTaggingMiddleware.new
end

class ExportReport < ApplicationTask
  required :report_id, coerce: :integer

  def work
    context.report = Report.includes(:line_items).find(report_id)
    context.csv    = ReportSerializer.new(context.report).to_csv
  end
end
```

## Notes

!!! tip "End-to-end correlation"

    `cmdx_xid` is the chain's external correlation id, resolved once by Runtime from `settings.correlation_id`. Pointing it at `Current.request_id` (or the inbound `traceparent`) stitches the SQL log line, the CMDx lifecycle log line, and the APM trace under one identifier.
