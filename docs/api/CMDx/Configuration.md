# Class: CMDx::Configuration
**Inherits:** Object
    

Configuration class that manages global settings for CMDx including
middlewares, callbacks, coercions, validators, breakpoints, backtraces, and
logging.


# Attributes
## backtrace[RW] [](#attribute-i-backtrace)
Returns whether to log backtraces for failed tasks.

**@return** [Boolean] true if backtraces should be logged


**@example**
```ruby
config.backtrace = true
```## backtrace_cleaner[RW] [](#attribute-i-backtrace_cleaner)
Returns the proc used to clean backtraces before logging.

**@return** [Proc, nil] The backtrace cleaner proc, or nil if not set


**@example**
```ruby
config.backtrace_cleaner = ->(bt) { bt.first(5) }
```## callbacks[RW] [](#attribute-i-callbacks)
Returns the callback registry for task lifecycle hooks.

**@return** [CallbackRegistry] The callback registry


**@example**
```ruby
config.callbacks.register(:before_execution, :log_start)
```## coercions[RW] [](#attribute-i-coercions)
Returns the coercion registry for type conversions.

**@return** [CoercionRegistry] The coercion registry


**@example**
```ruby
config.coercions.register(:custom, CustomCoercion)
```## exception_handler[RW] [](#attribute-i-exception_handler)
Returns the proc called when exceptions occur during execution.

**@return** [Proc, nil] The exception handler proc, or nil if not set


**@example**
```ruby
config.exception_handler = ->(task, error) { Sentry.capture_exception(error) }
```## logger[RW] [](#attribute-i-logger)
Returns the logger instance for CMDx operations.

**@return** [Logger] The logger instance


**@example**
```ruby
config.logger.level = Logger::DEBUG
```## middlewares[RW] [](#attribute-i-middlewares)
Returns the middleware registry for task execution.

**@return** [MiddlewareRegistry] The middleware registry


**@example**
```ruby
config.middlewares.register(CustomMiddleware)
```## rollback_on[RW] [](#attribute-i-rollback_on)
Returns the statuses that trigger a task execution rollback.

**@return** [Array<String>] Array of status names that trigger rollback


**@example**
```ruby
config.rollback_on = ["failed", "skipped"]
```## task_breakpoints[RW] [](#attribute-i-task_breakpoints)
Returns the breakpoint statuses for task execution interruption.

**@return** [Array<String>] Array of status names that trigger breakpoints


**@example**
```ruby
config.task_breakpoints = ["failed", "skipped"]
```## validators[RW] [](#attribute-i-validators)
Returns the validator registry for attribute validation.

**@return** [ValidatorRegistry] The validator registry


**@example**
```ruby
config.validators.register(:email, EmailValidator)
```## workflow_breakpoints[RW] [](#attribute-i-workflow_breakpoints)
Returns the breakpoint statuses for workflow execution interruption.

**@return** [Array<String>] Array of status names that trigger breakpoints


**@example**
```ruby
config.workflow_breakpoints = ["failed", "skipped"]
```
# Instance Methods
## initialize() [](#method-i-initialize)
Initializes a new Configuration instance with default values.

Creates new registry instances for middlewares, callbacks, coercions, and
validators. Sets default breakpoints and configures a basic logger.

**@return** [Configuration] a new Configuration instance


**@example**
```ruby
config = Configuration.new
config.middlewares.class # => MiddlewareRegistry
config.task_breakpoints # => ["failed"]
```## to_h() [](#method-i-to_h)
Converts the configuration to a hash representation.

**@return** [Hash<Symbol, Object>] hash containing all configuration values


**@example**
```ruby
config = Configuration.new
config.to_h
# => { middlewares: #<MiddlewareRegistry>, callbacks: #<CallbackRegistry>, ... }
```