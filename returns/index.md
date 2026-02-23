# Returns

Returns declare expected context outputs that must be present after a task executes successfully. If any declared return is missing from the context when `work` completes, the task fails with a validation error.

## Declaration

Use the `returns` class method to declare one or more expected context keys:

```ruby
class AuthenticateUser < CMDx::Task
  required :email, :password

  returns :source
  returns :user, :token

  def work
    context.source = email.include?("@mycompany.com") ? :admin_portal : :user_portal
    context.user = User.authenticate(email, password)
    context.token = JwtService.encode(user_id: context.user.id)
  end
end
```

## Validation Behavior

Return validation runs **after** `work` completes and **only** when the result is still successful. If the task has already failed or been skipped, return validation is skipped entirely.

```
flowchart LR
    W[work] --> C{success?}
    C -->|Yes| V{returns present?}
    C -->|No| Done[Skip validation]
    V -->|Yes| S[Success]
    V -->|No| F[Fail with errors]
```

### Missing Returns

When a declared return is missing from the context, the task fails with the same error format as attribute validation:

```ruby
class CreateUser < CMDx::Task
  returns :user

  def work
    # Forgot to set context.user
  end
end

result = CreateUser.execute
result.failed?  #=> true
result.reason   #=> "Invalid"
result.metadata #=> {
  #   errors: {
  #     full_message: "user must be set in the context",
  #     messages: { user: ["must be set in the context"] }
  #   }
  # }
```

### With Bang Execution

Missing returns raise a `CMDx::FailFault` when using `execute!`:

```ruby
begin
  AuthenticateUser.execute!(email: "user@example.com", password: "secret")
rescue CMDx::FailFault => e
  e.message #=> "Invalid"
  e.result.metadata[:errors][:messages]
  #=> { token: ["must be set in the context"] }
end
```
