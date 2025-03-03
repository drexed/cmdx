# Interruptions - Halt

Halting stops execution of a task. Halt methods signal the intent as to why a task
is stopped executing.

## Skip

The `skip!` method indicates that a task did not meet the criteria to continue execution.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    skip! if cart_abandoned?

    # Do work...
  end

end
```

## Fail

The `fail!` method indicates that a task met with incomplete, broken, or failed logic.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    fail! if cart_items_out_of_stock?

    # Do work...
  end

end
```

## Metadata

Pass metadata to enrich faults with additional contextual information. Metadata requires
that it be passed as a hash object. Internal failures will hydrate metadata into its result,
eg: failed validations and unrescued exceptions.

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    if cart_abandoned?
      skip!(reason: "Cart was abandoned due to 30 days of inactivity")
    elsif cart_items_out_of_stock?
      fail!(reason: "Items in the cart are out of stock", item: [123, 987])
    else
      # Do work...
    end
  end

end

result = ProcessOrderTask.call
result.metadata #=> { reason: "Items in the cart are out of stock", item: [123, 987] }
```

> [!Important]
> The `:reason` key is used to define the fault exception message. While not
> required, it is strongly recommended that it is used on every halt method.

## Results

The following represents a result output example of a halted task.

```ruby
result = ProcessOrderTask.call
result.status   #=> "failed"
result.metadata #=> { reason: "Cart was abandoned due to 30 days of inactivity" }
```

---

- **Prev:** [Basics - Run](https://github.com/drexed/cmdx/blob/main/docs/basics/run.md)
- **Next:** [Interruptions - Faults](https://github.com/drexed/cmdx/blob/main/docs/interruptions/faults.md)
