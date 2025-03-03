# Batch

A CMDx::Batch is a task that calls other tasks in a linear fashion. The
context is passed down to each task, building on it knowledge with
each step. This is useful for composing multiple steps into one call.

> [!WARNING]
> Do **NOT** define a call method in this class. The batch class automatically
> defines the call logic.

```ruby
class BatchProcessCheckout < CMDx::Batch

  # Task level settings:
  task_settings!(batch_halt: CMDx::Result::FAILED)

  # Single declaration:
  process FinalizeInvoiceTask

  # Multiple declarations:
  process SendConfirmationEmailTask, SendConfirmationTextTask

  # With options (applies to all declared in that group):
  process BatchNotifyPartnerWarehouses, batch_halt: [CMDx::Result::SKIPPED, CMDx::Result::FAILED]
  process BatchNotifyUsaWarehouses, unless: proc { context.invoice.fulfilled_in_house? }

end
```

> [!IMPORTANT]
> Process steps are executed in the order they are declared (FIFO: first in, first out).

The `process` method support the following options:

| Option        | Description |
| ------------- | ----------- |
| `:if`         | Specifies a callable method, proc or string to determine if processing steps should occur. |
| `:unless`     | Specifies a callable method, proc, or string to determine if processing steps should not occur. |
| `:batch_halt` | Sets which result statuses processing of further steps should be prevented. (default: `CMDx::Result::FAILED`) |

> [!NOTE]
> Batches stop execution on `failed` by default. This is due to the concept
> of `skipped` being a bypass mechanism, rather than a choke point in execution.

## Generator

Run `rails g cmdx:batch [NAME]` to create a batch template file under `app/cmds`.
Tasks will inherit from `ApplicationBatch` if available or fall back to `CMDx::Batch`.

---

- **Prev:** [Hooks](https://github.com/drexed/cmdx/blob/main/docs/hooks.md)
- **Next:** [Logging](https://github.com/drexed/cmdx/blob/main/docs/logging.md)
