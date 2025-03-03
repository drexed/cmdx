# Parameters - Validations

Parameter values can be validated using one of the built-in validators. Build custom validators
to check parameter values against your own business logic. `i18n` internalization is supported
out of the box.

Built-in validators are: [Presence](#presence), [Format](#format), [Exclusion](#exclusion),
[Inclusion](#inclusion), [Length](#length), [Numeric](#numeric), [Custom](#custom)

All validators support the following common options:

| Option       | Description |
| ------------ | ----------- |
| `:allow_nil` | Skip validation if the parameter value is `nil`. |
| `:if`        | Specifies a callable method, proc or string to determine if the validation should occur. |
| `:unless`    | Specifies a callable method, proc, or string to determine if the validation should not occur. |
| `:message`   | The error message to use for a violation. Fallback for any error key below that's not provided. |

> [!NOTE]
> Validators on `optional` parameters will only be executed if they are supplied as
> call arguments.

## Presence

Validates that the specified parameter value is not empty. If you want to validate the
presence of a boolean field (where the real values are true and false), you will
want to use `inclusion: { in: [true, false] }`.

```ruby
class UpdateUserDetailsTask < CMDx::Task

  # Boolean
  required :username, presence: true

  # With custom error message
  optional :email, presence: { message: "must not be empty" }

  def call
    # Do work...
  end

end
```

## Format

Validates whether the specified parameter value is of the correct form,
going by the regular expression provided.

```ruby
class UpdateUserDetailsTask < CMDx::Task

  # With
  required :username, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }

  # Without (with proc if conditional)
  optional :email, format: { without: /NOSPAM/, if: proc { Current.account.spam_check? } }

  def call
    # Do work...
  end

end
```

Constraint options:

| Option     | Description |
| ---------- | ----------- |
| `:with`    | Regular expression that if the parameter value matches will result in a successful validation. |
| `:without` | Regular expression that if the parameter value does not match will result in a successful validation. |

## Exclusion

Validates that the specified parameter is not in a particular enumerable object.

```ruby
class DetermineBoxSizeTask < CMDx::Task

  # Array
  required :width, exclusion: { in: [12, 24, 36] }

  # Range (with allow nil)
  optional :length, exclusion: { in: 12..36, allow_nil: true }

  def call
    # Do work...
  end

end
```

Constraint options:

| Option       | Description |
| ------------ | ----------- |
| `:in`        | An enumerable object of unavailable items such as an array or range. |
| `:within`    | A synonym (or alias) for `:in` |

Other options:

| Option            | Description |
| ----------------- | ----------- |
| `:of_message`     | The error message if the parameter value is in array. (default: "must not be one of: %{values}") |
| `:in_message`     | The error message if the parameter value is in range. (default: "must not be within %{min} and %{max}") |
| `:within_message` | A synonym (or alias) for `:in_message` |

## Inclusion

Validates that the specified parameter value is in a particular enumerable object.

```ruby
class DetermineBoxSizeTask < CMDx::Task

  # Array
  required :width, inclusion: { in: [12, 24, 36] }

  # Range (with custom error message)
  optional :length, inclusion: { in: 12..36, unless: :length_check? }

  def call
    # Do work...
  end

  private

  def skip_length_check?
    false
  end

end
```

Constraint options:

| Option       | Description |
| ------------ | ----------- |
| `:in`        | An enumerable object of available items such as an array or range. |
| `:within`    | A synonym (or alias) for `:in` |

Other options:

| Option            | Description |
| ----------------- | ----------- |
| `:of_message`     | The error message if the parameter value is not in array. (default: "must be one of: %{values}") |
| `:in_message`     | The error message if the parameter value is not in range. (default: "must be within %{min} and %{max}") |
| `:within_message` | A synonym (or alias) for `:in_message` |

## Length

Validates that the specified parameter value matches the length restrictions supplied.
Only one constraint option can be used at a time apart from `:min` and `:max`
that can be combined together:

```ruby
class UpdateUserDetailsTask < CMDx::Task

  # Range (with custom error message)
  required :email, length: { within: 12..36, message: "must be within range" }
  required :username, length: { not_within: 48..96 }

  # Boundary
  optional :first_name, length: { min: 24 }
  optional :middle_name, length: { max: 48 }
  optional :last_name, length: { min: 24, max: 48 }

  # Exact
  required :title, length: { is: 24 }
  required :count, length: { is_not: 48 }

  def call
    # Do work...
  end

end
```

Constraint options:

| Option        | Description |
| ------------- | ----------- |
| `:within`     | A range specifying the minimum and maximum size of the parameter value. |
| `:not_within` | A range specifying the minimum and maximum size of the parameter value it's not to be. |
| `:in`         | A synonym (or alias) for `:within` |
| `:not_in`     | A synonym (or alias) for `:not_within` |
| `:min`        | The minimum size of the parameter value. |
| `:max`        | The maximum size of the parameter value. |
| `:is`         | The exact size of the parameter value. |
| `:is_not`     | The exact size of the parameter value it's not to be. |

Other options:

| Option                | Description |
| --------------------- | ----------- |
| `:within_message`     | The error message if the parameter value is within the value range. (default: "length must not be within %{min} and %{max}") |
| `:not_within_message` | The error message if the parameter value is not within the value range. (default: "length must be within %{min} and %{max}") |
| `:in_message`         | A synonym (or alias) for `:within_message` |
| `:not_in_message`     | A synonym (or alias) for `:not_within_message` |
| `:min_message`        | The error message if the parameter value is below the min value. (default: "length must be at least %{min}") |
| `:max_message`        | The error message if the parameter value is above the min value. (default: "length must be at most %{max}") |
| `:is_message`         | The error message if the parameter value is the exact value. (default: "length must be %{is}") |
| `:is_not_message`     | The error message if the parameter value is not the exact value. (default: "length must not be %{is_not}") |

## Numeric

Validates that the specified parameter value matches the numeric restrictions supplied.
Only one constraint option can be used at a time apart from `:min` and `:max`
that can be combined together:

```ruby
class UpdateUserDetailsTask < CMDx::Task

  # Range (with custom error message)
  required :height, numeric: { within: 36..196 }
  required :weight, numeric: { not_within: 0..5 }

  # Boundary
  optional :dob_year, numeric: { min: 1900 }
  optional :dob_day, numeric: { max: 31 }
  optional :dob_month, numeric: { min: 1, max: 12 }

  # Exact
  required :age, numeric: { is: 18 }
  required :parents, numeric: { is_not: 0 }

  def call
    # Do work...
  end

end
```

Constraint options:

| Option        | Description |
| ------------- | ----------- |
| `:within`     | A range specifying the minimum and maximum size of the parameter value. |
| `:not_within` | A range specifying the minimum and maximum size of the parameter value it's not to be. |
| `:in`         | A synonym (or alias) for `:within` |
| `:not_in`     | A synonym (or alias) for `:not_within` |
| `:min`        | The minimum size of the parameter value. |
| `:max`        | The maximum size of the parameter value. |
| `:is`         | The exact size of the parameter value. |
| `:is_not`     | The exact size of the parameter value it's not to be. |

Other options:

| Option                | Description |
| --------------------- | ----------- |
| `:within_message`     | The error message if the parameter value is within the value range. (default: "must not be within %{min} and %{max}") |
| `:not_within_message` | The error message if the parameter value is not within the value range. (default: "must be within %{min} and %{max}") |
| `:in_message`         | A synonym (or alias) for `:within_message` |
| `:not_in_message`     | A synonym (or alias) for `:not_within_message` |
| `:min_message`        | The error message if the parameter value is below the min value. (default: "must be at least %{min}") |
| `:max_message`        | The error message if the parameter value is above the min value. (default: "must be at most %{max}") |
| `:is_message`         | The error message if the parameter value is the exact value. (default: "must be %{is}") |
| `:is_not_message`     | The error message if the parameter value is not the exact value. (default: "must not be %{is_not}") |

## Custom

Validate the specified parameter value using custom validators.

```ruby
class TLDValidator
  def self.call(value, options)
    tld = options.dig(:custom, :tld) || %w[com]
    value.ends_with?(tld)
  end
end

class UpdateUserDetailsTask < CMDx::Task

  # Basic
  required :unconfirmed_email, custom: { validator: TLDValidator }

  # Passable options (with custom error message)
  optional :confirmed_email, custom: { validator: TLDValidator, tld: %w[com net org], message: "is not valid" }

  def call
    # Do work...
  end

end
```

Constraint options:

| Option       | Description |
| ------------ | ----------- |
| `:validator` | Callable class that returns true or false. |

## Results

The following represents a result output example of a failed validation.

```ruby
result = DetermineBoxSizeTask.call
result.state    #=> "interrupted"
result.status   #=> "failed"
result.metadata #=> {
                #=>   reason: "email format is not valid. username cannot be empty.",
                #=>   messages: {
                #=>     email: ["format is not valid"],
                #=>     username: ["cannot be empty"]
                #=>   }
                #=> }
```

---

- **Prev:** [Coercions](https://github.com/drexed/cmdx/blob/main/docs/parameters/coercions.md)
- **Next:** [Defaults](https://github.com/drexed/cmdx/blob/main/docs/parameters/defaults.md)
