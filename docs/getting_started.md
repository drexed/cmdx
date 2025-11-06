# Getting Started

CMDx is a Ruby framework for building maintainable, observable business logic through composable command objects. It brings structure, consistency, and powerful developer tools to your business processes.

**Common challenges:**

- Inconsistent service object patterns across your codebase
- Black boxes make debugging a nightmare
- Fragile error handling erodes confidence

**What you get:**

- Consistent, standardized architecture
- Built-in flow control and error handling
- Composable, reusable workflows
- Comprehensive logging for observability
- Attribute validation with type coercions
- Sensible defaults and developer-friendly APIs

## Installation

Add CMDx to your Gemfile:

```sh
gem install cmdx

# - or -

bundle add cmdx
```

## Configuration

For Rails applications, run the following command to generate a global configuration file in `config/initializers/cmdx.rb`.

```bash
rails generate cmdx:install
```

If not using Rails, manually copy the [configuration file](https://github.com/drexed/cmdx/blob/main/lib/generators/cmdx/templates/install.rb).

## The CERO Pattern

CMDx embraces the Compose, Execute, React, Observe (CERO, pronounced "zero") pattern—a simple yet powerful approach to building reliable business logic.

### Compose

Define small, focused tasks *(optional: attributes, validations, etc)*

```ruby
class AnalyzeMetrics < CMDx::Task
  def work
    # Your logic here...
  end
end
```

### Execute

Run tasks that result in clear outcomes

```ruby
# Without args
result = AnalyzeMetrics.execute

# With args
result = AnalyzeMetrics.execute(model: "blackbox", "sensitivity" => 3)
```

### React

Optionally handle task outcomes with operations

```ruby
if result.success?
  # Handle success
elsif result.skipped?
  # Handle skipped
elsif result.failed?
  # Handle failed
end
```

### Observe

Capture structured logs and execution chains for analysis and debugging

```log
I, [2022-07-17T18:42:37.000000 #3784] INFO -- CMDx:
index=1 chain_id="018c2b95-23j4-2kj3-32kj-3n4jk3n4jknf" type="Task" class="SendAnalyzedEmail" state="complete" status="success" metadata={runtime: 347}

I, [2022-07-17T18:43:15.000000 #3784] INFO -- CMDx:
index=0 chain_id="018c2b95-b764-7615-a924-cc5b910ed1e5" type="Task" class="AnalyzeMetrics" state="complete" status="success" metadata={runtime: 187}
```

## Task Generator

Generate new CMDx tasks quickly using the built-in generator:

```bash
rails generate cmdx:task ModerateBlogPost
```

This creates a new task file with the basic structure:

```ruby
# app/tasks/moderate_blog_post.rb
class ModerateBlogPost < CMDx::Task
  def work
    # Your logic here...
  end
end
```

!!! tip

    Use **present tense verbs + noun** for task names, eg: `ModerateBlogPost`, `ScheduleAppointment`, `ValidateDocument`

## Type safety

CMDx includes built-in RBS (Ruby Type Signature) inline annotations throughout the codebase, providing type information for static analysis and editor support.

- **Type checking** — Catch type errors before runtime using tools like Steep or TypeProf
- **Better IDE support** — Enhanced autocomplete, navigation, and inline documentation
- **Self-documenting code** — Clear method signatures and return types
- **Refactoring confidence** — Type-aware refactoring reduces bugs
