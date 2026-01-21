# OpenAPI Schema Generation

This example demonstrates how to use the `CMDx::Attribute#to_h` method to introspect your command's attributes and generate an OpenAPI (Swagger) compatible schema definition. This is useful for automatically documenting your API endpoints based on your command objects.

## Example Command

First, let's define a command with various attribute types, including nested attributes and validations.

```ruby
require 'cmdx'
require 'json'

class CreateUser < CMDx::Command
  required :email, types: String, description: "The user's email address"
  required :age, types: Integer, description: "The user's age in years"
  optional :newsletter, types: [TrueClass, FalseClass], description: "Subscribe to newsletter", default: false

  required :address, types: Hash, description: "User's physical address" do
    required :street, types: String, description: "Street name and number"
    required :city, types: String, description: "City name"
    optional :zip_code, types: [String, Integer], description: "Postal code"
  end

  def call
    # implementation details...
  end
end
```

## Schema Generator

Now, let's create a simple generator that converts `CMDx` attributes into OpenAPI schema property definitions.

```ruby
class OpenApiGenerator
  TYPE_MAPPING = {
    String => 'string',
    Integer => 'integer',
    Float => 'number',
    TrueClass => 'boolean',
    FalseClass => 'boolean',
    Array => 'array',
    Hash => 'object'
  }

  def self.generate_properties(command_class)
    properties = {}
    required_fields = []

    # Iterate over all attributes defined in the command
    # attributes are stored in the settings[:attributes] registry
    command_class.settings[:attributes].registry.each do |attribute|
      # Use to_h to get the raw attribute data
      data = attribute.to_h

      name = data[:name]
      prop_def = {
        description: data[:description]
      }

      # Handle Types
      types = data[:types]
      if types.any?
        # Simple type mapping for the first type found, or 'string' fallback
        # In a real generator, you might handle multiple types (oneOf)
        mapped_type = TYPE_MAPPING[types.first] || 'string'
        prop_def[:type] = mapped_type
      end

      # Handle Nested Attributes (if type is object/Hash)
      if data[:children].any?
        prop_def[:type] = 'object'
        nested_props, nested_required = generate_nested_properties(data[:children])
        prop_def[:properties] = nested_props
        prop_def[:required] = nested_required unless nested_required.empty?
      end

      properties[name] = prop_def
      required_fields << name if data[:required]
    end

    {
      type: 'object',
      properties: properties,
      required: required_fields
    }
  end

  def self.generate_nested_properties(children_data)
    properties = {}
    required_fields = []

    children_data.each do |child_data|
      name = child_data[:name]
      prop_def = {
        description: child_data[:description]
      }

      types = child_data[:types]
      if types.any?
        mapped_type = TYPE_MAPPING[types.first] || 'string'
        prop_def[:type] = mapped_type
      end

      # Recursion for deeper nesting would go here if needed

      properties[name] = prop_def
      required_fields << name if child_data[:required]
    end

    [properties, required_fields]
  end
end
```

## Usage

Generate the schema and output it as JSON.

```ruby
schema = OpenApiGenerator.generate_properties(CreateUser)
puts JSON.pretty_generate(schema)
```

## Output

The resulting JSON schema structure:

```json
{
  "type": "object",
  "properties": {
    "email": {
      "description": "The user's email address",
      "type": "string"
    },
    "age": {
      "description": "The user's age in years",
      "type": "integer"
    },
    "newsletter": {
      "description": "Subscribe to newsletter",
      "type": "boolean"
    },
    "address": {
      "description": "User's physical address",
      "type": "object",
      "properties": {
        "street": {
          "description": "Street name and number",
          "type": "string"
        },
        "city": {
          "description": "City name",
          "type": "string"
        },
        "zip_code": {
          "description": "Postal code",
          "type": "string"
        }
      },
      "required": [
        "street",
        "city"
      ]
    }
  },
  "required": [
    "email",
    "age",
    "address"
  ]
}
```
