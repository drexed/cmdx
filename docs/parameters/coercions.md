# Parameters - Coercions

Parameter values will be returned as given (`type: :virtual`) but can be coerced (typecast)
to a specific type. This is useful for casting stringified parameter values.

Supported coercions are: `:array`, `:big_decimal`, `:boolean`, `:complex`, `:datetime`, `:date`,
`:float`, `:hash`, `:integer`, `:rational`, `:string`, `:time`, `:virtual`

```ruby
class DetermineBoxSizeTask < CMDx::Task

  # Single type
  required :width, type: :string

  # Multiple types
  optional :height, type: [:float, :integer]

  def call
    width  #=> "1"
    height #=> 2.3
  end

end

# Coerced to value types
DetermineBoxSizeTask.call(width: 1, height: "2.3")
```

> [!NOTE]
> When passing multiple type, coercions are done in the order they are passed. An example of
> numeric casting would be to cast numbers with precision first: `[:float, :integer]`

## Results

The following represents a result output example of a failed coercion.

```ruby
result = DetermineBoxSizeTask.call
result.state    #=> "interrupted"
result.status   #=> "failed"
result.metadata #=> {
                #=>   reason: "height could not be coerced into one of: float, integer.",
                #=>   messages: {
                #=>     height: ["could not be coerced into one of: float, integer"]
                #=>   }
                #=> }
```

---

- **Prev:** [Namespacing](https://github.com/drexed/cmdx/blob/main/docs/parameters/namespacing.md)
- **Next:** [Validations](https://github.com/drexed/cmdx/blob/main/docs/parameters/validations.md)
