# Parameters - Defaults

Assign default values for parameters that return a `nil` value.

```ruby
class DetermineBoxSizeTask < CMDx::Task

  # Fixed value
  required :width, default: 12

  # Proc or lambda
  optional :length, default: -> { Current.account.usa? ? 12 : 18 }

  # Symbol or string
  optional :depth, default: :depth_by_country

  def call
    width  #=> 12
    length #=> 18
    depth  #=> 48
  end

  private

  def depth_by_country
    case Current.account.country
    when "usa" then 12
    when "can" then 18
    when "mex" then 24
    else 48
    end
  end

end

# Initializes with default values
DetermineBoxSizeTask.call(width: nil, length: nil)
```

> [!NOTE]
> Defaults are subject to coercion and validations so take care setting
> the fallback value to contain valid conditions.

---

- **Prev:** [Validations](https://github.com/drexed/cmdx/blob/main/docs/parameters/validations.md)
- **Next:** [Results](https://github.com/drexed/cmdx/blob/main/docs/outcomes.md)
