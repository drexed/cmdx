# Attributes - Naming

Attribute naming provides method name customization to prevent conflicts and enable flexible attribute access patterns. When attributes share names with existing methods or when multiple attributes from different sources have the same name, affixing ensures clean method resolution within tasks.

> [!NOTE]
> Affixing modifies only the generated accessor method names within tasks.

## Table of Contents

- [Prefix](#prefix)
- [Suffix](#suffix)
- [As](#as)

## Prefix

Adds a prefix to the generated accessor method name.

```ruby
class UpdateCustomer < CMDx::Task
  # Dynamic from attribute source
  attribute :id, prefix: true

  # Static
  attribute :name, prefix: "customer_"

  def work
    context_id    #=> 123
    customer_name #=> "Jane Smith"
  end
end

# Attributes passed as original attribute names
UpdateCustomer.execute(id: 123, name: "Jane Smith")
```

## Suffix

Adds a suffix to the generated accessor method name.

```ruby
class UpdateCustomer < CMDx::Task
  # Dynamic from attribute source
  attribute :email, suffix: true

  # Static
  attribute :phone, suffix: "_number"

  def work
    email_context #=> "jane@example.com"
    phone_number  #=> "555-0123"
  end
end

# Attributes passed as original attribute names
UpdateCustomer.execute(email: "jane@example.com", phone: "555-0123")
```

## As

Completely renames the generated accessor method.

```ruby
class UpdateCustomer < CMDx::Task
  attribute :birthday, as: :bday

  def work
    bday #=> <Date>
  end
end

# Attributes passed as original attribute names
UpdateCustomer.execute(birthday: Date.new(2020, 10, 31))
```

---

- **Prev:** [Attributes - Definitions](definitions.md)
- **Next:** [Attributes - Coercions](coercions.md)
