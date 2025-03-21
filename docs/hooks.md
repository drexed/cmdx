# Hooks

Hooks (callbacks) run logic at task transition points. Callable hooks have access
to all the same information as the `call` method.

> [!TIP]
> Hooks are inheritable which is handy for setting up global logic execution,
> eg: setting tracking markers, account plan checks, etc.

```ruby
class ProcessOrderTask < CMDx::Task

  # Symbol or string declaration:
  after_validation :verify_message_starting_chars

  # Proc or lambda declaration:
  on_complete -> { send_telemetry_data }

  # Multiple declarations:
  on_success :increment_success_task_counter, :scrub_secret_message_data

  # With options (applies to all declared in that group):
  on_failure :increment_failure_task_counter, if: :worth_keep_track?

  def call
    # Do work...
  end

end
```

The hook methods support the following options:

| Option        | Description |
| ------------- | ----------- |
| `:if`         | Specifies a callable method, proc or string to determine if hook processing should occur. |
| `:unless`     | Specifies a callable method, proc, or string to determine if hook processing should not occur. |

## Order

Hook types are executed in the following order:

```ruby
0. before_execution
1. on_executing
2. before_validation
3. after_validation
4. on_[complete, interrupted]
5. on_executed
6. on_[success, skipped, failed]
7. on_good
8. on_bad
9. after_execution
```

> [!IMPORTANT]
> Callable hooks are executed in the order they are declared (FIFO: first in, first out).

---

- **Prev:** [Outcomes - States](https://github.com/drexed/cmdx/blob/main/docs/outcomes/states.md)
- **Next:** [Batch](https://github.com/drexed/cmdx/blob/main/docs/batch.md)
