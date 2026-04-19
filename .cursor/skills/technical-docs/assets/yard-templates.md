# YARD Documentation Templates

## Class / Module

No `@example` or `@since` at class/module level. Do not document the top-level `module CMDx`.

```ruby
# Brief one-sentence purpose.
#
# Longer description if the class has non-obvious behavior, lifecycle,
# or freeze semantics worth calling out.
#
# @see RelatedClass
class MyClass
```

## Public Method (simple)

```ruby
# Symbolizes and stores +value+ under +key+, overwriting any existing entry.
#
# @param key [Symbol, String] the context key (converted to Symbol)
# @param value [Object] the value to store
# @return [Object] the stored value
def store(key, value)
```

## Public Method (with block)

```ruby
# Executes the task and yields the result to the block if given.
#
# @param context [Hash{Symbol => Object}] initial context values
# @option context [Integer] :user_id the user to process
# @yield [result] invoked after execution completes
# @yieldparam result [Result] the frozen execution result
# @return [Result] the execution result
#
# @example
#   MyTask.execute(user_id: 1) do |result|
#     result.on(:success) { |r| log(r.context) }
#   end
#
# @see .execute!
def self.execute(context = {}, &)
```

## Public Method (hash param with @option)

```ruby
# Initializes the context from a hash, symbolizing all keys.
#
# @param context [Hash{Symbol => Object}] key-value pairs for the context
# @option context [Array<Symbol>] :executed list of completed task names
# @option context [String] :reason human-readable explanation
# @return [Context] the initialized context
def initialize(context = EMPTY_HASH)
```

## Bang Method (raises)

```ruby
# Executes the task. Raises on skip or failure instead of returning
# an interrupted result.
#
# @param context [Hash{Symbol => Object}] initial context values
# @return [Result] the execution result (always complete/success)
# @raise [SkipFault] when the task signals skip
# @raise [FailFault] when the task signals failure or an exception occurs
#
# @see .execute
def self.execute!(context = {}, &)
```

## Signal Method (never returns)

```ruby
# Signals a successful halt with optional reason and metadata.
#
# Throws +:cmdx+ — control never returns to the caller.
# Calling after a signal was already thrown raises RuntimeError.
#
# @param reason [String, nil] human-readable explanation
# @param metadata [Hash{Symbol => Object}] arbitrary metadata attached to the result
# @return [void] method never returns
# @raise [RuntimeError] if a signal was already thrown in this execution
#
# @note Uses +throw(Signal::TAG)+ — must be called inside a +catch(:cmdx)+ block
#   managed by Runtime.
def success!(reason = nil, **metadata)
```

## Abstract / Template Method

```ruby
# Performs the task's core logic. Subclasses must override this method.
#
# Access context via +ctx+ or +context+. Mutate with +ctx.store+,
# +ctx.merge+, +ctx.delete+. Signal outcomes with +success!+, +skip!+,
# or +fail!+.
#
# @abstract Override in subclasses to define task behavior.
# @return [void]
# @raise [ImplementationError] if not overridden
def work
```

## Predicate Method

```ruby
# Whether the execution completed without interruption.
#
# @return [Boolean]
def complete?
```

## Pattern Matching

```ruby
# Deconstructs the result into a positional array for pattern matching.
#
# @return [Array(String, String, String, Hash, Exception)]
#   +[state, status, reason, metadata, cause]+
#
# @example
#   case result
#   in ["complete", "success", *]
#     handle_success
#   in [*, "failed", reason, *]
#     handle_failure(reason)
#   end
def deconstruct(*)
```

## Factory / Builder

```ruby
# Builds a {Context} from the given input. Reuses an unfrozen Context
# as-is. Unwraps objects responding to +#context+. Wraps hashes into
# a new Context with symbolized keys.
#
# @param context [Context, #context, Hash, #to_h] the input to normalize
# @return [Context] a mutable context instance
# @raise [ArgumentError] if +context+ responds to neither +to_h+ nor +to_hash+
def self.build(context = EMPTY_HASH)
```

## Dynamic Accessor (method_missing)

```ruby
# Provides dynamic read/write/predicate access to context keys.
#
# - +ctx.name+ — reads +@table[:name]+, returns +nil+ if missing.
# - +ctx.name = val+ — stores +val+ under +:name+.
# - +ctx.name?+ — returns +true+ if +@table[:name?]+ is truthy.
#
# @note Returns +nil+ for missing keys — use +#key?+ or +#fetch+ for
#   presence checks to avoid silent nils.
#
# @api private
def method_missing(method_name, *args, **_kwargs, &)
```

## Callback / Chaining

```ruby
# Dispatches to the block when any of +keys+ match a truthy predicate
# on this result. Returns +self+ for chaining.
#
# @param keys [Array<Symbol>] predicate names (without +?+ suffix)
# @yield [result] invoked if any predicate returns true
# @yieldparam result [Result] this result instance
# @return [Result] self for chaining
# @raise [ArgumentError] if no block given
#
# @example
#   result
#     .on(:success) { |r| notify(r.context) }
#     .on(:failed)  { |r| alert(r.reason) }
def on(*keys, &)
```

## CHANGELOG Entry

```markdown
## [Unreleased]

### Added

- `Context#retrieve` — fetch-or-store accessor with lazy default via block.
- `Result#on` — predicate-based callback dispatch with chaining support.

### Changed

- `Context#merge` — now returns `self` instead of the merged hash for chaining.

### Fixed

- `Context#method_missing` — predicate suffix (`?`) now checks `@table[:key?]` correctly.
```
