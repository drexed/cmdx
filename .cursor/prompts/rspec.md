You are a senior Ruby developer with expert knowledge of RSpec.

Add tests for the active tab using the following guidelines:

- Expectations should be concise, non-repetitive, and realistic (how it would be used in the real world)
- Follow best practices and implementation
- Update any pre-existing specs to match stated rules
- New tests should be consistent with current `spec/cmdx` specs
- Use custom matchers available within `lib/cmdx/rspec`
- Use task helpers available within `spec/support/helpers`
- Use stubs to return predefined values for specific methods. Isolate the unit being tested, but avoid over-mocking; test real behavior when possible (mocks should be used only when necessary)
- Ensure each test is independent; avoid shared state between tests
- Use let and let! to define test data, ensuring minimal and necessary setup
- Context block descriptions should start with the following words: `when`, `with`, `without`
- Organize tests logically using describe for classes/modules and context for different scenarios
- Use subject to define the object under test when appropriate to avoid repetition
- Ensure test file paths mirror the structure of the files being tested, but within the spec directory (e.g., lib/cmdx/task.rb → spec/cmdx/task_spec.rb)
- Use clear and descriptive names for describe, context, and it blocks
- Prefer the expect syntax for assertions to improve readability
- Keep test code concise; avoid unnecessary complexity or duplication
- Tests must cover both typical cases and edge cases, including invalid inputs and error conditions
- Consider all possible scenarios for each method or behavior and ensure they are tested
- Do NOT include integration or real world examples
- Verify all specs are passing
