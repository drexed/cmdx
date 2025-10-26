# Stoplight Circuit Breaker

Integrate circuit breakers to protect external service calls and prevent cascading failures when dependencies are unavailable.

<https://github.com/bolshakov/stoplight>

### Setup

```ruby
# lib/cmdx_stoplight_middleware.rb
class CmdxStoplightMiddleware
  def self.call(task, **options, &)
    light = Stoplight(options[:name] || task.class.name, **options)
    light.run(&)
  rescue Stoplight::Error::RedLight => e
    task.result.tap { |r| r.fail!("[#{e.class}] #{e.message}", cause: e) }
  end
end
```

### Usage

```ruby
class MyTask < CMDx::Task
  # With default options
  register :middleware, CmdxStoplightMiddleware

  # With stoplight options
  register :middleware, CmdxStoplightMiddleware, cool_off_time: 10

  def work
    # Do work...
  end

end
```
