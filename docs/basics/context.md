# Basics - Context

The task `context` provides a form of storage to the task objects themselves.

## Loading

Loading a task with data is as simple as passing objects in a key value format.
The context object is a custom version of an [OpenStruct](https://github.com/ruby/ostruct)
called a `LazyStruct` with no limitations for what can be stored.

```ruby
ProcessOrderTask.call(email: "bob@bigcorp.com", order: order)
```

## Access

Tasks with a loaded context can be accessed within a task itself. Read, set and
alter the context attributes anywhere within the task object.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    # Reading from context storage:
    context.email #=> "bob@bigcorp.com"
    ctx.order     #=> <Order #a1b2c3d>
    context.idk   #=> nil

    # Writing to context storage:
    context.first_name = "Bob"
    ctx.middle_name ||= "Biggie"
    context.merge!(last_name: "Boomer")
  end

end
```

[Learn more](https://github.com/drexed/cmdx/blob/main/lib/cmdx/lazy_struct.rb)
about the `LazyStruct` public API for interacting with the context.

> [!NOTE]
> Attributes that are **NOT** loaded into the context will return `nil`.

## Passing

Context objects can be passed to other tasks which allows you to build small tasks
that passes data around as part of a higher level task.

```ruby
# Within task:
class ProcessOrderTask < CMDx::Task

  def call
    SendEmailConfirmationTask.call(context)
  end

end

# After call:
result = ProcessOrderTask.call(email: "bob@bigcorp.com", order: order)
NotifyPartnerWarehousesTask.call(result.ctx)
```

---

- **Prev:** [Basics - Call](https://github.com/drexed/cmdx/blob/main/docs/basics/call.md)
- **Next:** [Basics - Run](https://github.com/drexed/cmdx/blob/main/docs/basics/run.md)
