# Outcomes -  States

State represents the condition of all the code task should execute.

| Status        | Description |
| ------------- | ----------- |
| `initialized` | Initial task state prior to any execution. |
| `executing`   | Task is actively executing code. |
| `complete`    | Task executed to completion without halting for any reason. |
| `interrupted` | Task could **NOT** be executed to completion due to a fault/exception. |

> [!CAUTION]
> States are automatically transitioned and should **NEVER** be altered manually.

```ruby
result = ProcessOrderTask.call
result.state        #=> "complete"

result.pending?     #=> false
result.executing?   #=> false
result.complete?    #=> true
result.interrupted? #=> false

# `complete` or `interrupted`
result.executed?
```

---

- **Prev:** [Outcomes - Statuses](https://github.com/drexed/cmdx/blob/main/docs/outcomes/statuses.md)
- **Next:** [Hooks](https://github.com/drexed/cmdx/blob/main/docs/hooks.md)
