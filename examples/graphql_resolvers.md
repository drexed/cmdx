# GraphQL Resolvers

A GraphQL mutation should validate input, perform one piece of work, and return a payload. Pushing the second step into a CMDx task keeps the resolver a five-line adapter and gives the same operation a callable handle for jobs, scripts, and tests.

## Mutation recipe

```ruby
# app/graphql/mutations/application_mutation.rb
# frozen_string_literal: true

class Mutations::ApplicationMutation < GraphQL::Schema::Mutation
  def self.payload_for(result, **extras)
    if result.success?
      { success: true, errors: [] }.merge(extras)
    else
      { success: false, errors: user_errors(result) }
    end
  end

  def self.user_errors(result)
    field_errors = result.errors.to_h.flat_map do |field, messages|
      messages.map { |message| { message:, path: ["input", field.to_s] } }
    end

    field_errors.presence || [{ message: result.reason, path: [] }]
  end
end
```

```ruby
# app/graphql/mutations/create_invoice.rb
# frozen_string_literal: true

class Mutations::CreateInvoice < Mutations::ApplicationMutation
  argument :customer_id,  ID,      required: true
  argument :amount_cents, Integer, required: true

  field :invoice, Types::InvoiceType,    null: true
  field :success, Boolean,               null: false
  field :errors,  [Types::UserErrorType], null: false

  def resolve(**args)
    result = CreateInvoice.execute(**args, current_user: context[:current_user])

    self.class.payload_for(result, invoice: result.context.invoice)
  end
end
```

## Notes

!!! tip "Trace ids in development"

    Expose `result.tid` and `result.cid` on a debug field (or as an error extension) outside production. A single id turns one log line into a full trace through the resolver, the task, and any nested tasks it dispatches.

!!! warning "Don't use execute! in resolvers"

    `execute!` raises `CMDx::Fault` on failure. graphql-ruby converts unhandled exceptions into opaque `InternalError` payloads, hiding `result.reason`. Always prefer `execute` and translate the `Result` into a payload yourself.
