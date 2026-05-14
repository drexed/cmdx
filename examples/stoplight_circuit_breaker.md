# Stoplight Circuit Breaker

When a downstream service degrades, retrying every request piles latency onto the caller and load onto the dependency. A [Stoplight](https://github.com/bolshakov/stoplight) circuit breaker counts failures, opens after a threshold, and short-circuits subsequent calls until a cool-off elapses — so a partial outage stops cascading.

## Setup

```ruby
# app/middlewares/cmdx_stoplight_middleware.rb
# frozen_string_literal: true

class CmdxStoplightMiddleware
  def initialize(name: nil, **options)
    @name    = name
    @options = options
  end

  def call(task)
    light_name = @name || task.class.name

    Stoplight(light_name, **@options).run { yield }
  rescue Stoplight::Error::RedLight => e
    task.errors.add(:base, "circuit open: #{e.message}")
    task.metadata.merge!(code: :circuit_open, light: light_name)
    yield
  end
end
```

## Usage

```ruby
class FetchInventory < CMDx::Task
  register :middleware, CmdxStoplightMiddleware.new(
    cool_off_time: 10,
    threshold:     3
  )

  required :sku, coerce: :string

  def work
    context.inventory = InventoryClient.fetch(sku, timeout: 2)
  end
end

result = FetchInventory.execute(sku: "ABC-123")
result.failed?              # => true while the breaker is open
result.metadata[:code]      # => :circuit_open
```

## Notes

!!! note "Failed, not raised"

    When the light is red, the middleware records the breaker error on `task.errors` and yields. `signal_errors!` halts the task as **failed** during input resolution; `execute!` callers see the same failure surface as `CMDx::Fault`.

!!! tip "Production data store"

    Stoplight defaults to an in-memory data store, which means each process has its own breaker — a half-degraded cluster never opens consistently. Configure `Stoplight::Light.default_data_store = Stoplight::DataStore::Redis.new(Redis.current)` once at boot so every worker shares state.
