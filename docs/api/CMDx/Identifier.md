# Module: CMDx::Identifier
  
**Extended by:** CMDx::Identifier
    

Generates unique identifiers for tasks, workflows, and other CMDx components.

The Identifier module provides a consistent way to generate unique identifiers
across the CMDx system, with fallback support for different Ruby versions.


# Class Methods
## generate() [](#method-c-generate)
Generates a unique identifier string.
**@raise** [StandardError] If SecureRandom is unavailable or fails to generate an identifier

**@return** [String] A unique identifier string (UUID v7 if available, otherwise UUID v4)


**@example**
```ruby
CMDx::Identifier.generate
# => "01890b2c-1234-5678-9abc-def123456789"
```
# Instance Methods
## generate() [](#method-i-generate)
Generates a unique identifier string.

**@raise** [StandardError] If SecureRandom is unavailable or fails to generate an identifier

**@return** [String] A unique identifier string (UUID v7 if available, otherwise UUID v4)


**@example**
```ruby
CMDx::Identifier.generate
# => "01890b2c-1234-5678-9abc-def123456789"
```