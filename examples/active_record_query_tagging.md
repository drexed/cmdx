# Active Record Query Tagging

Add a comment to every query indicating some context to help you track down where that query came from, eg:

```sh
/*cmdx_task_class:ExportReportTask,cmdx_chain_id:018c2b95-b764-7615*/ SELECT * FROM reports WHERE id = 1
```

### Setup

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags += [
  :cmdx_correlation_id,
  :cmdx_chain_id,
  :cmdx_task_class,
  :cmdx_task_id
]

# lib/cmdx_query_tagging_middleware.rb
class CmdxQueryTaggingMiddleware
  def self.call(task, **options, &)
    ActiveSupport::ExecutionContext.set(
      cmdx_correlation_id: task.result.metadata[:correlation_id],
      cmdx_chain_id: task.chain.id,
      cmdx_task_class: task.class.name,
      cmdx_task_id: task.id,
      &
    )
  end
end
```

### Usage

```ruby
class MyTask < CMDx::Task
  register :middleware, CmdxQueryTaggingMiddleware

  def work
    # Do work...
  end

end
```
