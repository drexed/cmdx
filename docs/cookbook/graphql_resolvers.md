# GraphQL Resolvers

A GraphQL mutation should do three things: accept input, run business logic once, and return a payload the client understands.

Put the business logic in a CMDx task. The resolver stays a thin adapter — and the same task remains callable from jobs, rake tasks, and specs.

## Setup — shared payload helper

Map a `Result` to a consistent shape: `success`, `errors`, plus any extra fields (like the created record).

```ruby
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

## Usage

Task on the inside, resolver on the outside:

```ruby
class CreateInvoice < CMDx::Task
  required :customer_id,  coerce: :integer
  required :amount_cents, coerce: :integer

  def work
    context.invoice = Invoice.create!(customer_id:, amount_cents:)
  end
end
```

```ruby
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

### Trace ids in development

Expose `result.tid` and `result.cid` on a debug field (or error extension) outside production. One id links the resolver log line to the task log line and any nested tasks.

### Don't use `execute!` in resolvers

`execute!` raises `CMDx::Fault` on failure. graphql-ruby turns unhandled exceptions into opaque internal errors and hides `result.reason`. Prefer `execute` and translate the `Result` yourself.
