# Parameters - Namespacing

Parameter namespacing provides method name customization to prevent conflicts
and enable flexible parameter access patterns. When parameters share names with
existing methods or when multiple parameters from different sources have the
same name, namespacing ensures clean method resolution within tasks.

## Namespacing Fundamentals

The `:prefix` and `:suffix` options modify the generated accessor method names
while preserving the original parameter names for call arguments. This separation
allows for flexible method naming without affecting the task interface.

### Fixed Value Namespacing

Use string or symbol values to add consistent prefixes or suffixes to parameter
method names:

```ruby
class NamespaceExampleTask < CMDx::Task

  # Fixed prefix
  required :width, prefix: "box_"
  required :height, prefix: :container_

  # Fixed suffix
  required :length, suffix: "_measurement"
  required :depth, suffix: :_dimension

  # Combined prefix and suffix
  required :weight, prefix: "item_", suffix: "_kg"

  def call
    # Generated method names with namespacing
    box_width              #=> accesses width parameter
    container_height       #=> accesses height parameter
    length_measurement     #=> accesses length parameter
    depth_dimension        #=> accesses depth parameter
    item_weight_kg         #=> accesses weight parameter
  end

end

# Call arguments use original parameter names
NamespaceExampleTask.call(
  width: 10,
  height: 20,
  length: 30,
  depth: 5,
  weight: 2.5
)
```

### Dynamic Source-Based Namespacing

Use `true` value to automatically generate prefixes or suffixes based on the
parameter source name:

```ruby
class SourceNamespaceTask < CMDx::Task

  # Automatic prefix from default source (:context)
  required :name, prefix: true           # Generates: context_name

  # Automatic suffix from custom source
  required :title, source: :user, suffix: true  # Generates: title_user

  # Combined automatic namespacing
  required :email, source: :account, prefix: true, suffix: true  # Generates: account_email_account

  def call
    context_name    #=> accesses context.name
    title_user      #=> accesses user.title
    account_email_account  #=> accesses account.email
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def account
    @account ||= user.account
  end

end

# Call arguments still use original parameter names
SourceNamespaceTask.call(
  user_id: 123,
  name: "John Doe",
  title: "Manager",
  email: "john@company.com"
)
```

## Conflict Resolution

Namespacing is essential when dealing with method name conflicts or when
accessing multiple objects with similar attribute names:

### Method Name Conflicts

```ruby
class ConflictResolutionTask < CMDx::Task

  # Avoid conflict with Ruby's built-in 'name' method
  required :name, prefix: "user_"

  # Avoid conflict with custom private methods
  required :status, suffix: "_param"

  # Avoid conflict with Rails helper methods
  required :url, prefix: "target_"

  def call
    user_name     #=> parameter value, not Ruby's Object#name
    status_param  #=> parameter value, not custom status method
    target_url    #=> parameter value, not Rails url helper
  end

  private

  def status
    "active"  # Custom method that would conflict without suffix
  end

end
```

### Multiple Source Disambiguation

```ruby
class MultiSourceTask < CMDx::Task

  # User information
  required :name, source: :user, prefix: "user_"
  required :email, source: :user, prefix: "user_"
  required :phone, source: :user, prefix: "user_"

  # Company information
  required :name, source: :company, prefix: "company_"
  required :email, source: :company, prefix: "company_"
  required :phone, source: :company, prefix: "company_"

  # Order information
  required :status, source: :order, suffix: "_order"
  required :total, source: :order, suffix: "_order"

  def call
    # Clear disambiguation of same-named attributes
    user_name       #=> user.name
    company_name    #=> company.name

    user_email      #=> user.email
    company_email   #=> company.email

    status_order    #=> order.status
    total_order     #=> order.total
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def company
    @company ||= user.company
  end

  def order
    @order ||= user.orders.find(context.order_id)
  end

end
```

## Advanced Namespacing Patterns

### Hierarchical Namespacing

Combine namespacing with nested parameters for complex data structures:

```ruby
class HierarchicalNamespaceTask < CMDx::Task

  # Primary address with prefix
  required :primary_address, source: :user, prefix: "primary_" do
    required :street, :city, :state
    optional :apartment
  end

  # Secondary address with suffix
  optional :secondary_address, source: :user, suffix: "_secondary" do
    required :street, :city, :state
    optional :apartment
  end

  def call
    # Namespaced parent access
    primary_primary_address    #=> user.primary_address
    secondary_address_secondary #=> user.secondary_address

    # Child parameters inherit parent namespacing context
    street     #=> depends on which address context is active
    city       #=> depends on which address context is active

    # Access specific address data
    if primary_primary_address
      primary_street = street  # primary_address.street
      primary_city = city      # primary_address.city
    end
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

end
```

### Conditional Namespacing

Apply namespacing based on runtime conditions:

```ruby
class ConditionalNamespaceTask < CMDx::Task

  # Different namespacing for different parameter types
  required :id,
    prefix: -> { context.id_type == "user" ? "user_" : "order_" }

  required :reference,
    suffix: -> { context.environment == "production" ? "_prod" : "_dev" }

  def call
    # Method names determined at runtime
    if context.id_type == "user"
      user_id       #=> accesses id parameter
    else
      order_id      #=> accesses id parameter
    end

    if context.environment == "production"
      reference_prod #=> accesses reference parameter
    else
      reference_dev  #=> accesses reference parameter
    end
  end

end
```

## Namespacing with Validation and Coercion

Namespacing works seamlessly with all parameter features:

```ruby
class NamespacedValidationTask < CMDx::Task

  # Namespaced parameters with full validation
  required :user_email,
    source: :user,
    prefix: "validated_",
    type: :string,
    format: { with: /@/ },
    presence: true

  required :account_balance,
    source: :account,
    suffix: "_amount",
    type: :float,
    numeric: { min: 0.0 },
    default: 0.0

  # Nested namespaced parameters
  required :shipping_info, prefix: "order_" do
    required :method,
      type: :string,
      inclusion: { in: %w[standard express overnight] }

    required :address, type: :hash do
      required :street, :city, type: :string, presence: true
      required :zip, type: :string, format: { with: /\A\d{5}\z/ }
    end
  end

  def call
    # All features work with namespaced methods
    validated_user_email   #=> validated and coerced email from user
    account_balance_amount #=> validated float with default from account
    order_shipping_info    #=> validated nested shipping information

    # Nested parameters maintain validation
    method  #=> validated shipping method
    street  #=> validated non-empty street
    zip     #=> validated 5-digit zip code
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

  def account
    @account ||= user.account
  end

end
```

## Introspection and Debugging

Namespaced parameters maintain full introspection capabilities:

```ruby
class NamespaceIntrospectionTask < CMDx::Task

  required :name, prefix: "user_", source: :user
  required :email, suffix: "_address", source: :user
  optional :phone, prefix: "contact_", suffix: "_number"

  def call
    # Parameter introspection shows original names
    params = self.class.cmd_parameters

    params.map(&:name)           #=> [:name, :email, :phone] (original names)
    params.map(&:method_name)    #=> [:user_name, :email_address, :contact_phone_number]

    # Method name generation details
    name_param = params.first
    name_param.name              #=> :name
    name_param.method_name       #=> :user_name
    name_param.method_source     #=> :user

    # Access both original and generated names
    respond_to?(:name)           #=> false (original name not generated)
    respond_to?(:user_name)      #=> true (namespaced method generated)
  end

  private

  def user
    @user ||= User.find(context.user_id)
  end

end
```

## Error Handling with Namespacing

Parameter validation errors reference original parameter names:

```ruby
class NamespaceErrorTask < CMDx::Task

  required :email,
    prefix: "user_",
    type: :string,
    format: { with: /@/ }

  required :age,
    suffix: "_years",
    type: :integer,
    numeric: { min: 18 }

  def call
    # Business logic here
  end

end

# Invalid parameters
result = NamespaceErrorTask.call(
  email: "invalid-email",
  age: "not-a-number"
)

result.failed?  #=> true
result.metadata
#=> {
#     reason: "email format is not valid. age could not coerce into an integer.",
#     messages: {
#       email: ["format is not valid"],    # Original parameter name
#       age: ["could not coerce into an integer"]  # Original parameter name
#     }
#   }

# But access uses namespaced methods
# result.task.user_email    # Would access the email parameter
# result.task.age_years     # Would access the age parameter
```

## Best Practices

### When to Use Namespacing

- **Method conflicts**: When parameter names conflict with existing methods
- **Multiple sources**: When accessing similar attributes from different objects
- **Clarity**: When method names need to be more descriptive than parameter names
- **Organization**: When grouping related parameters for better code organization

### Namespacing Strategies

- **Consistent patterns**: Use consistent prefix/suffix patterns across related parameters
- **Source-based**: Use automatic source-based namespacing for multi-source tasks
- **Descriptive names**: Choose prefixes/suffixes that clearly indicate parameter purpose
- **Avoid over-namespacing**: Don't add unnecessary namespacing that makes code verbose

### Performance Considerations

- **Method generation**: Namespaced methods are generated at class definition time
- **Runtime overhead**: No runtime performance impact for namespaced method access
- **Memory usage**: Each namespaced parameter creates one additional method definition
- **Introspection**: Namespacing doesn't affect parameter introspection performance

### Documentation and Maintenance

- **Document namespacing**: Clearly document namespacing patterns in complex tasks
- **Consistent naming**: Use consistent namespacing conventions across the codebase
- **Refactor carefully**: Changing namespacing affects method names throughout the task
- **Test thoroughly**: Ensure tests cover both parameter validation and method access

---

- **Prev:** [Parameters - Definitions](https://github.com/drexed/cmdx/blob/main/docs/parameters/definitions.md)
- **Next:** [Parameters - Coercions](https://github.com/drexed/cmdx/blob/main/docs/parameters/coercions.md)
