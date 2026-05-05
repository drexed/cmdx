# OpenAPI Schema Generation

Project a task's `inputs_schema` into an OpenAPI property definition so your API docs stay in lockstep with the task contract.

## Example Task

```ruby
class CreateUser < CMDx::Task
  required :email,      coerce: :string,                description: "The user's email address"
  required :age,        coerce: :integer,               description: "The user's age in years"
  optional :newsletter, coerce: :boolean, default: false, description: "Subscribe to newsletter"

  required :address, coerce: :hash, description: "User's physical address" do
    required :street,   coerce: :string,                 description: "Street name and number"
    required :city,     coerce: :string,                 description: "City name"
    optional :zip_code, coerce: [:string, :integer],     description: "Postal code"
  end

  def work
    # ...
  end
end
```

## Generator

One recursive method walks `inputs_schema` and emits an OpenAPI `object` schema. Each input's `:options` hash carries the `:coerce` declaration — map its first symbol to an OpenAPI primitive.

```ruby
# lib/openapi_schema_generator.rb
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

  def self.generate(task_class)
    build_object(task_class.inputs_schema.values)
  end

  def self.build_object(inputs)
    properties = {}
    required   = []

    inputs.each do |input|
      properties[input[:name]] = build_property(input)
      required << input[:name] if input[:required]
    end

    { type: "object", properties:, required: }
  end

  def self.build_property(input)
    prop   = { description: input[:description] }.compact
    coerce = Array(input.dig(:options, :coerce)).first
    prop[:type] = COERCE_TO_TYPE.fetch(coerce, "string") if coerce

    if input[:children].any?
      prop[:type]       = "object"
      nested            = build_object(input[:children])
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
    "email":      { "description": "The user's email address", "type": "string" },
    "age":        { "description": "The user's age in years",  "type": "integer" },
    "newsletter": { "description": "Subscribe to newsletter",  "type": "boolean" },
    "address": {
      "description": "User's physical address",
      "type": "object",
      "properties": {
        "street":   { "description": "Street name and number", "type": "string" },
        "city":     { "description": "City name",              "type": "string" },
        "zip_code": { "description": "Postal code",            "type": "string" }
      },
      "required": ["street", "city"]
    }
  },
  "required": ["email", "age", "address"]
}
```

## Notes

!!! tip

    `inputs_schema` returns `{ name, description, required, options, children }` per input — the full declaration options sit under `:options`, so you can extend the generator to emit `format`, `enum`, `default`, etc. straight from validator/default keys (see [Inputs — Definitions](../docs/inputs/definitions.md#introspection)).
