# Parameters - Namespacing

Parameters can have the delegated method prefixed and/or suffixed to
prevent clashing where the source object have methods with the same name.

`:prefix` and `:suffix` can be used independently or both at the same time.

## With fixed value

```ruby
class DetermineBoxSizeTask < CMDx::Task

  required :width, prefix: :before_
  required :height, suffix: "_after"

  def call
    before_width #=> 1
    height_after #=> 2
  end

end

# Call arguments match the parameter names
DetermineBoxSizeTask.call(width: 1, height: 2)
```

## With source name

```ruby
class DetermineBoxSizeTask < CMDx::Task

  # Default (:context) as source
  optional :height, prefix: true

  # Custom source
  optional :width, source: :account, suffix: true

  def call
    context_height #=> 1
    width_account  #=> 2
  end

end

# Call arguments match the parameter names
account = Account.new(width: 2)
DetermineBoxSizeTask.call(height: 1, account: account)
```

> [!NOTE]
> `:prefix` or `:suffix` with a custom source and a fixed value
> will always return the fixed value without the source.

---

- **Prev:** [Definitions](https://github.com/drexed/cmdx/blob/main/docs/parameters/definitions.md)
- **Next:** [Coercions](https://github.com/drexed/cmdx/blob/main/docs/parameters/coercions.md)
