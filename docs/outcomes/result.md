# Outcomes -  Result

The result object is returned after a task execution. This is the main object
that will be interacted with post call.

```ruby
result = ProcessOrderTask.call
result.task     #=> <ProcessOrderTask ...>
result.context  #=> <CMDx::Context ...>
result.metadata #=> { ... }
result.run      #=> <CMDx::Run ...>
```

---

- **Prev:** [Interruptions - Exceptions](https://github.com/drexed/cmdx/blob/main/docs/interruptions/exceptions.md)
- **Next:** [Outcomes - Statuses](https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md)
