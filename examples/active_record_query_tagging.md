# Active Record Query Tagging

Annotate every SQL query emitted during a task's execution so the task class, task id, chain id, and correlation id show up in your database logs:

```sql
/*cmdx_task:ExportReport,cmdx_tid:018c2b95-b764-...,cmdx_cid:018c2b95-0878-...*/ SELECT * FROM reports WHERE id = 1
```

## Setup

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags += %i[cmdx_task cmdx_tid cmdx_cid cmdx_xid]

# app/middlewares/cmdx_query_tagging_middleware.rb
class CmdxQueryTaggingMiddleware
  def call(task)
    ActiveSupport::ExecutionContext.set(
      cmdx_task: task.class.name,
      cmdx_tid:  task.tid,
      cmdx_cid:  CMDx::Chain.current.id,
      cmdx_xid: task.metadata[:correlation_id],
    ) { yield }
  end
end
```

## Usage

```ruby
class ExportReport < CMDx::Task
  register :middleware, CmdxQueryTaggingMiddleware.new

  def work
    # ...
  end
end
```

## Notes

!!! tip

    Pair `cmdx_cid` with your APM's correlation field. CMDx's default log line already emits the same `cid`, so a single id stitches the SQL log, the lifecycle log, and the APM trace together.
