# Basics - Call

Calling a task executes the logic within it. Tasks can only be executed via
the `call` and `call!` class methods.

## Non-bang

The `call` method will always return a `CMDx::Result` object after execution.

```ruby
ProcessOrderTask.call #=> <CMDx::Result ...>
```

## Bang

The bang `call!` method raises a `CMDx::Fault` based exception depending on the defined
`task_halt` status options, otherwise it will return a `CMDx::Result` object. This
form of call is useful in background jobs where retries are done via the exception mechanism.

```ruby
ProcessOrderTask.call! #=> raises CMDx::Failed
```

> [!IMPORTANT]
> Tasks are single use objects, once they have been called they are frozen and cannot be called again
> as result object will be returned. Build a new task call to execute a new instance of the same task.

---

- **Prev:** [Basics - Setup](https://github.com/drexed/cmdx/blob/main/docs/basics/setup.md)
- **Next:** [Basics - Context](https://github.com/drexed/cmdx/blob/main/docs/basics/context.md)
