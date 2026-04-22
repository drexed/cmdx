# GraphQL Resolvers

Use CMDx tasks as the business logic layer behind [graphql-ruby](https://graphql-ruby.org/) mutations and resolvers. The resolver stays thin: parse arguments, delegate, translate the `Result` into a payload.

## Mutation Recipe

```ruby
# app/graphql/mutations/application_mutation.rb
class Mutations::ApplicationMutation < GraphQL::Schema::Mutation
  # Normalize a CMDx::Result into a mutation payload with
  # `{ success:, errors:, ... }` — fields your schema expects.
  def self.result_payload(result)
    if result.success?
      { success: true, errors: [] }.merge(result.context.to_h)
    else
      {
        success: false,
        errors: result.errors.full_messages.presence ||
                [{ message: result.reason, path: [] }]
      }
    end
  end
end
```

```ruby
# app/graphql/mutations/create_invoice.rb
class Mutations::CreateInvoice < Mutations::ApplicationMutation
  argument :customer_id, ID, required: true
  argument :amount_cents, Integer, required: true

  field :invoice, Types::InvoiceType, null: true
  field :success, Boolean, null: false
  field :errors,  [Types::UserErrorType], null: false

  def resolve(**args)
    result = CreateInvoice.execute(
      **args,
      current_user: context[:current_user]
    )

    self.class.result_payload(result).tap do |payload|
      payload[:invoice] = result.context.invoice
    end
  end
end
```

## Surfacing Validation Errors

`Task#errors` aggregates coercion/validation/output errors per input key — perfect for GraphQL field-level user errors.

```ruby
def self.result_payload(result)
  return { success: true, errors: [] }.merge(result.context.to_h) if result.success?

  field_errors = result.errors.to_hash.flat_map do |field, messages|
    messages.map { |m| { message: m, path: ["input", field.to_s] } }
  end

  {
    success: false,
    errors:  field_errors.presence || [{ message: result.reason, path: [] }]
  }
end
```

## Notes

!!! tip

    Expose `result.tid` (task id) and `result.chain.id` (correlation id) on a debug field or in an error extension in non-production environments — they turn a single log line into a full trace.

!!! warning

    Don't raise `Fault` in a resolver (`execute!`). Schema-level raises become `InternalError` in GraphQL and hide the actual reason. Use `execute` and translate the `Result` yourself.
