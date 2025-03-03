# Getting Start

`CMDx` is a framework for expressive processing of business logic.

Goals:
- Provide easy branching, nesting, and composition of complex tasks
- Supply intent, severity, and reasoning to halting execution of tasks
- Demystify root causes of complex multi-level tasks with exhaustive tracing

## Setup

```ruby
class ProcessOrderTask < CMDx::Task

  def call
    fail!(reason: "Order was canceled") if context.order.canceled?
    skip!(reason: "Order is processing") if context.order.processing?

    inform_partner_warehouses
    send_confirmation_email
  end

end
```

## Execution

```ruby
result = ProcessOrderTask.call(order: order)
```

## Result

```ruby
if result.failed?
  flash[:error] = "Failed! #{result.metadata[:reason]}"
elsif result.skipped?
  flash[:notice] = "FYI: #{result.metadata[:reason]}"
else
  flash[:success] = "Order successfully processed"
end
```

---

- **Prev:** [Example](https://github.com/drexed/cmdx/blob/main/docs/example.md)
- **Next:** [Configuration](https://github.com/drexed/cmdx/blob/main/docs/configuration.md)
