# OpenAPI Schema Generation

A task already declares its inputs as a typed contract. Projecting that contract into an OpenAPI schema means the API documentation can never drift from the validation the request will actually face — change a `required`, the docs change next deploy.

## Example task

```ruby
class CreateUser < CMDx::Task
  required :email, coerce: :string, description: "Primary email address",
           validate: { format: URI::MailTo::EMAIL_REGEXP }
  required :age,   coerce: :integer, description: "Age in years",
           validate: { numericality: { greater_than_or_equal_to: 13 } }
  optional :newsletter, coerce: :boolean, default: false,
           description: "Subscribe to the product newsletter"

  required :address, description: "Shipping address" do
    required :street,   coerce: :string,                description: "Street name and number"
    required :city,     coerce: :string,                description: "City"
    optional :zip_code, coerce: %i[string integer],     description: "Postal code"
  end

  def work
    context.user = User.create!(email:, age:, newsletter:, address:)
  end
end
```

## Generator

`inputs_schema` returns one entry per declared input as `{ name:, description:, required:, options:, children: }`. Walking that recursively turns it into a nested OpenAPI `object`. Coerce arrays project to the first symbol — that's enough for the common case; extend the map for `format`, `enum`, etc.

```ruby
# lib/openapi_schema_generator.rb
# frozen_string_literal: true

class OpenApiSchemaGenerator
  COERCE_TO_TYPE = {
    string:      "string",
    symbol:      "string",
    date:        "string",
    date_time:   "string",
    time:        "string",
    integer:     "integer",
    float:       "number",
    big_decimal: "number",
    boolean:     "boolean",
    array:       "array",
    hash:        "object"
  }.freeze
  private_constant :COERCE_TO_TYPE

  def self.generate(task_class)
    new.build_object(task_class.inputs_schema.values)
  end

  def build_object(inputs)
    properties = {}
    required   = []

    inputs.each do |input|
      properties[input[:name]] = build_property(input)
      required << input[:name] if input[:required]
    end

    { type: "object", properties:, required: }
  end

  def build_property(input)
    prop   = { description: input[:description] }.compact
    coerce = Array(input.dig(:options, :coerce)).first
    prop[:type] = COERCE_TO_TYPE.fetch(coerce, "string") if coerce

    unless input[:children].empty?
      nested            = build_object(input[:children])
      prop[:type]       = "object"
      prop[:properties] = nested[:properties]
      prop[:required]   = nested[:required] unless nested[:required].empty?
    end

    prop
  end
end
```

## Usage

```ruby
puts JSON.pretty_generate(OpenApiSchemaGenerator.generate(CreateUser))
```

```json
{
  "type": "object",
  "properties": {
    "email":      { "description": "Primary email address",          "type": "string" },
    "age":        { "description": "Age in years",                   "type": "integer" },
    "newsletter": { "description": "Subscribe to the product newsletter", "type": "boolean" },
    "address": {
      "description": "Shipping address",
      "type": "object",
      "properties": {
        "street":   { "description": "Street name and number", "type": "string" },
        "city":     { "description": "City",                   "type": "string" },
        "zip_code": { "description": "Postal code",            "type": "string" }
      },
      "required": ["street", "city"]
    }
  },
  "required": ["email", "age", "address"]
}
```

## Notes

!!! tip "Beyond the basics"

    `:options` carries the full declaration verbatim — `:default`, `:validate`, `:if` — so the generator can extend straight to `default`, `enum` (`inclusion: { in: [...] }`), `pattern` (`format: { with: /.../ }`), and `minimum`/`maximum` (`numericality:`). See [Inputs — Definitions](../docs/inputs/definitions.md#introspection).
