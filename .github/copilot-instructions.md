# Ruby Coding Standards

Follow the official Ruby gem guides for best practices.
Reference the guides outlined in https://guides.rubygems.org

## Project Context
CMDx provides a framework for designing and executing complex
business logic within service/command objects.

## Technology Stack
- Ruby 3.4+
- RSpec 3.1+

## Code Style and Structure
- Write concise, idiomatic Ruby code with accurate examples
- Follow Ruby conventions and best practices
- Use object-oriented and functional programming patterns as appropriate
- Prefer iteration and modularization over code duplication
- Use descriptive variable and method names (e.g., user_signed_in?, calculate_total)
- Write comprehensive code documentation using the Yardoc format

## Naming Conventions
- Use snake_case for file names, method names, and variables
- Use CamelCase for class and module names

## Syntax and Formatting
- Follow the Ruby Style Guide (https://rubystyle.guide/)
- Follow Ruby style conventions (2-space indentation, snake_case methods)
- Use Ruby's expressive syntax (e.g., unless, ||=, &.)
- Prefer double quotes for strings
- Respect my Rubocop options

## Performance Optimization
- Use memoization for expensive operations

## Testing
- Follow the RSpec Style Guide (https://rspec.rubystyle.guide/)
- Write comprehensive tests using RSpec
- Include both BDD and TDD based tests
- Create test objects to share across tests
- Do NOT make tests for obvious or reflective expectations
- Update tests and update Yardocs as your write code

## Documentation
- Utilize the YARDoc format when documenting Ruby code
- Follow these best practices:
  - Avoid redundant comments that merely restate the code
  - Keep comments up-to-date with code changes
  - Keep documentation consistent
