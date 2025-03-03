## Parameters - Definitions

Parameters provide a contract to verify that a task only executes if the arguments
of a call match.

## Basics

Parameters are defined based on methods that can be delegated to a source object
(default `:context`) or keys on a hash. Parameters are automatically defined as
attributes within the task instance. `optional` parameters that do not respond or
missing the hash key will still delegate but return `nil` as a value.

```ruby
class DetermineBoxSizeTask < CMDx::Task

  # Must be passed as call arguments
  required :material

  # Returns value if passed as a call arguments, else returns nil
  optional :depth

  # Define multiple parameters one line
  optional :width, :height

  def call
    material #=> "cardboard"
    depth    #=> nil
    height   #=> 12
    width    #=> 24
  end

end

# Initializes local variables matching the parameter name
DetermineBoxSizeTask.call(material: "cardboard", height: 12, width: 24)
```

## Source

Parameters will be delegated to the task context by default but any delegatable
object within the task will do.

```ruby
class UpdateUserDetailsTask < CMDx::Task

  # Default (:context)
  required :user

  # Defined parameter
  required :email, source: :user

  # Proc or lambda
  optional :address, source: -> { user.address }

  # Symbol or string
  optional :name, source: :company

  def call
    user    #=> <User #a1b2c3d>
    email   #=> "bill@bigcorp.com"
    address #=> "123 Maple St, Miami, Fl 33023"
    name    #=> "Big Corp."
  end

  private

  def company
    user.account.company
  end

end

# Hash or delegatable object
user = User.new(email: "bill@bigcorp.com")
UpdateUserDetailsTask.call(user: user)
```

## Nesting

Nesting builds upon parameter source option. Build complex parameter blocks that
delegate to the parent parameter automatically.

```ruby
class UpdateUserDetailsTask < CMDx::Task

  required :address do
    required :street1
    optional :street2
  end

  optional :locality do
    required :city, :state # Required if locality argument is passed
    optional :zipcode
  end

  def call
    address  #=> { city: "Miami", state: "Fl" }
    street1  #=> "123 Maple St."
    street2  #=> nil

    locality #=> { city: "Miami", state: "Fl" }
    city     #=> "Miami"
    state    #=> "Fl"
    zipcode  #=> nil
  end

end

# Hash or delegatable object
address = Address.new(street1: "123 Maple St.")
locality = { city: "Miami", state: "Fl" }
UpdateUserDetailsTask.call(address: address, locality: locality)
```

> [!NOTE]
> Optional parent parameters that have required child parameters will only have
> the child parameters be required if the parent option is a delegatable source
> or default value.

---

- **Prev:** [Parameters](https://github.com/drexed/cmdx/blob/main/docs/parameters.md)
- **Next:** [Namespacing](https://github.com/drexed/cmdx/blob/main/docs/parameters/namespacing.md)
