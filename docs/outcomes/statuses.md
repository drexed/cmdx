# Outcomes -  Statuses

Status represents the state of the task logic executed after its called.
A status of `success` is returned even if the task has **NOT** been executed.

| Status    | Description |
| --------- | ----------- |
| `success` | Call execution completed without fault/exception. |
| `skipped` | Task stopped completion of call execution early where proceeding is pointless. |
| `failed`  | Task stopped completion of call execution due to an unsatisfied/invalid condition or a `StandardError`. |

> [!NOTE]
> Statuses (except success) are paired with halt methods used to stop call execution.

```ruby
result = ProcessOrderTask.call
result.status   #=> "skipped"

result.success? #=> false
result.skipped? #=> true
result.failed?  #=> false

# `success` or `skipped`
result.good?    #=> true

# `skipped` or `failed`
result.bad?     #=> true
```

---

- **Prev:** [Outcomes - Result](https://github.com/drexed/cmdx/blob/main/docs/outcomes/result.md)
- **Next:** [Outcomes - States](https://github.com/drexed/cmdx/blob/main/docs/outcomes/states.md)
