# Stoplight Circuit Breaker

Wrap a task in a [Stoplight](https://github.com/bolshakov/stoplight) circuit breaker to shed load when a downstream dependency is misbehaving.

## Setup

```ruby
# app/middlewares/cmdx_stoplight_middleware.rb
class CmdxStoplightMiddleware
  def initialize(**options)
    @options = options
  end

  def call(task)
    name = @options[:name] || task.class.name
    Stoplight(name, **@options).run { yield }
  rescue Stoplight::Error::RedLight => e
    task.errors.add(:base, "[#{e.class}] #{e.message}")
    yield
  end
end
```

## Usage

```ruby
class FetchInventory < CMDx::Task
  register :middleware, CmdxStoplightMiddleware.new(cool_off_time: 10)

  def work
    # ...
  end
end
```

## Notes

!!! note

    When the light is red, the middleware records the breaker error on `task.errors` and `yield`s. `signal_errors!` picks the error up during input resolution and halts with a **failed** result; `execute!` surfaces it as `CMDx::Fault`.

!!! tip

    Stoplight itself needs a data store for production use (`Stoplight::DataStore::Redis`, etc.). Configure it once at boot — the middleware only wires the breaker around each execution.
