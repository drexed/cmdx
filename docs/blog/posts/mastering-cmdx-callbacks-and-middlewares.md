---
date: 2026-02-11
authors:
  - drexed
categories:
  - Tutorials
slug: mastering-cmdx-callbacks-and-middlewares
---

# Mastering CMDx Callbacks and Middlewares: Hooks and Wrappers

When I'm writing complex business logic in Ruby, I often find that the core "work" is only half the battle. The other half is everything around it: logging, error handling, notifications, database transactions, and performance tracking.

If you put all that code inside your main method, you end up with a mess. That's where CMDx's **Callbacks** and **Middlewares** come in. They let you separate the "what" from the "how" and the "when," keeping your tasks clean and focused.

Let's dive into how you can use these tools to write better service objects.

<!-- more -->

## Callbacks: Reacting to the Lifecycle

Callbacks are your hooks into specific moments of a task's lifecycle. They are perfect for "side effects"—things that should happen *because* the task ran, but aren't the main purpose of the task itself.

Imagine a task that approves a user's application.

```ruby
class ApproveApplication < CMDx::Task
  def work
    # The core logic
    application = context.application
    application.update!(status: :approved)

    # The side effects (cluttering the work method)
    UserMailer.approval_email(application.user).deliver_later
    SlackNotifier.notify("Application approved: #{application.id}")
  end
end
```

This works, but it mixes concerns. Let's clean it up with callbacks:

```ruby
class ApproveApplication < CMDx::Task
  # React to success
  on_success :send_email, :notify_team

  def work
    context.application.update!(status: :approved)
  end

  private

  def send_email
    UserMailer.approval_email(context.application.user).deliver_later
  end

  def notify_team
    SlackNotifier.notify("Application approved: #{context.application.id}")
  end
end
```

Now, your `work` method is pure business logic. CMDx handles the rest.

### Common Callbacks

You have access to a rich lifecycle:

- `before_execution`: Great for setting up data (e.g., finding records).
- `on_success`: Run code only when things go well.
- `on_failed`: Handle errors or logic failures (e.g., logging).
- `on_complete`: Runs whether it succeeded or failed (great for cleanup).

!!! warning "Execution Order"

    Callbacks execute in declaration order (FIFO). If you register multiple callbacks of the same type, they will run sequentially.

```ruby
class ProcessPayment < CMDx::Task
  before_execution :find_user
  on_failed :log_error
  on_complete :close_connection

  def work
    # ...
  end
end
```

## Middlewares: Wrapping the Execution

While callbacks react to *events*, **Middlewares** wrap the entire execution *process*. Think of them like layers of an onion around your task.

Middlewares are best for "cross-cutting concerns"—logic that applies to the execution environment itself, like timeouts, retries, or transactions.

Let's say you want to ensure a task doesn't run forever. You *could* write timeout logic inside `work`, or you could just wrap it:

```ruby
class GenerateReport < CMDx::Task
  # Built-in timeout middleware
  register :middleware, CMDx::Middlewares::Timeout, seconds: 5

  def work
    # Expensive reporting logic...
  end
end
```

If the task takes longer than 5 seconds, the middleware interrupts it. The task logic doesn't even need to know the timeout exists.

### Creating Custom Middleware

You can write your own middleware easily. It just needs to yield to the next step.

```ruby
class TransactionMiddleware
  def call(task, options)
    ActiveRecord::Base.transaction do
      yield # Run the task (or the next middleware)
    end
  end
end

class CreateUser < CMDx::Task
  register :middleware, TransactionMiddleware

  def work
    User.create!(context.params)
    Profile.create!(context.params)
  end
end
```

The execution flow works like this:
1. `TransactionMiddleware` starts.
2. It opens a transaction.
3. `yield` runs the task (`CreateUser`).
4. If the task finishes, the transaction commits.
5. If the task raises an error, the transaction rolls back.

## Conclusion

By leveraging callbacks and middlewares, this class tells a story. You can see at a glance that it's time-boxed, monitored, and has clear success/failure paths—all before you even look at the `work` method.

That's the CMDx way: clean, composable, and easy to read.

## References

- [Callbacks Documentation](https://drexed.github.io/cmdx/callbacks/)
- [Middlewares Documentation](https://drexed.github.io/cmdx/middlewares/)
