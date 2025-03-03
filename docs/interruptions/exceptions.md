# Interruptions - Exceptions

## Non-bang call

Any unhandled exception will be caught and halted using `fail!`.
The original exception will be passed as metadata of the result object.

```ruby
result = ProcessOrderTask.call
result.state    #=> "interrupted"
result.status   #=> "failed"
result.metadata #=> {
                #=>   reason: "[RuntimeError] method xyz is not defined",
                #=>   original_exception: <RuntimeError message="method xyz is not defined">
                #=> }
```

## Bang call

Any unhandled exception from a `call!` method will be raised as is.

```ruby
ProcessOrderTask.call! #=> raises NoMethodError, "method xyz is not defined"
```

---

- **Prev:** [Interruptions - Faults](https://github.com/drexed/cmdx/blob/main/docs/interruptions/faults.md)
- **Next:** [Outcomes - Result](https://github.com/drexed/cmdx/blob/main/docs/outcomes/result.md)
