# Module: CMDx::Middlewares::Correlate
  
**Extended by:** CMDx::Middlewares::Correlate
    

Middleware for correlating task executions with unique identifiers.

The Correlate middleware provides thread-safe correlation ID management for
tracking task execution flows across different operations. It automatically
generates correlation IDs when none are provided and stores them in task
result metadata for traceability.


# Class Methods
## call(task , **options ) [](#method-c-call)
Middleware entry point that applies correlation ID logic to task execution.

Evaluates the condition from options and applies correlation ID handling if
enabled. Generates or retrieves correlation IDs based on the :id option and
stores them in task result metadata.
**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Task] The task being executed

**@param** [Hash] Configuration options for correlation

**@return** [Object] The result of task execution

**@yield** [] The task execution block


**@example**
```ruby
Correlate.call(task, &block)
```
**@example**
```ruby
Correlate.call(task, id: "custom-123", &block)
```
**@example**
```ruby
Correlate.call(task, id: :correlation_id, &block)
```
**@example**
```ruby
Correlate.call(task, id: -> { "dynamic-#{Time.now.to_i}" }, &block)
```
**@example**
```ruby
Correlate.call(task, if: :enable_correlation, &block)
```## clear() [](#method-c-clear)
Clears the current correlation ID from thread-local storage.
**@return** [nil] Always returns nil


**@example**
```ruby
Correlate.clear
```## id() [](#method-c-id)
Retrieves the current correlation ID from thread-local storage.
**@return** [String, nil] The current correlation ID or nil if not set


**@example**
```ruby
Correlate.id # => "550e8400-e29b-41d4-a716-446655440000"
```## id=(id ) [](#method-c-id=)
Sets the correlation ID in thread-local storage.
**@param** [String] The correlation ID to set

**@return** [String] The set correlation ID


**@example**
```ruby
Correlate.id = "abc-123-def"
```## use(new_id ) [](#method-c-use)
Temporarily uses a new correlation ID for the duration of a block. Restores
the previous ID after the block completes, even if an error occurs.
**@param** [String] The correlation ID to use temporarily

**@return** [Object] The result of the yielded block

**@yield** [] The block to execute with the new correlation ID


**@example**
```ruby
Correlate.use("temp-id") do
  # Operations here use "temp-id"
  perform_operation
end
# Previous ID is restored
```
# Instance Methods
## call(task, **options) [](#method-i-call)
Middleware entry point that applies correlation ID logic to task execution.

Evaluates the condition from options and applies correlation ID handling if
enabled. Generates or retrieves correlation IDs based on the :id option and
stores them in task result metadata.

**@option** [] 

**@option** [] 

**@option** [] 

**@param** [Task] The task being executed

**@param** [Hash] Configuration options for correlation

**@return** [Object] The result of task execution

**@yield** [] The task execution block


**@example**
```ruby
Correlate.call(task, &block)
```
**@example**
```ruby
Correlate.call(task, id: "custom-123", &block)
```
**@example**
```ruby
Correlate.call(task, id: :correlation_id, &block)
```
**@example**
```ruby
Correlate.call(task, id: -> { "dynamic-#{Time.now.to_i}" }, &block)
```
**@example**
```ruby
Correlate.call(task, if: :enable_correlation, &block)
```## clear() [](#method-i-clear)
Clears the current correlation ID from thread-local storage.

**@return** [nil] Always returns nil


**@example**
```ruby
Correlate.clear
```## id() [](#method-i-id)
Retrieves the current correlation ID from thread-local storage.

**@return** [String, nil] The current correlation ID or nil if not set


**@example**
```ruby
Correlate.id # => "550e8400-e29b-41d4-a716-446655440000"
```## id=(id) [](#method-i-id=)
Sets the correlation ID in thread-local storage.

**@param** [String] The correlation ID to set

**@return** [String] The set correlation ID


**@example**
```ruby
Correlate.id = "abc-123-def"
```## use(new_id) [](#method-i-use)
Temporarily uses a new correlation ID for the duration of a block. Restores
the previous ID after the block completes, even if an error occurs.

**@param** [String] The correlation ID to use temporarily

**@return** [Object] The result of the yielded block

**@yield** [] The block to execute with the new correlation ID


**@example**
```ruby
Correlate.use("temp-id") do
  # Operations here use "temp-id"
  perform_operation
end
# Previous ID is restored
```