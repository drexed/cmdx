# Upgrading to CMDx 2.0

Version 2.0 is a **breaking** rewrite: same goals (composable command objects, workflows, outcomes), different internals and several API changes. This guide maps concepts, not line-for-line APIs.

## Mental model

- **Definition** replaces `Settings` plus multiple registries. Coercions, validators, and middleware are merged through `ExtensionSet` on each task class.
- **Session** carries `context`, `errors`, `outcome`, and **Trace** (explicit correlation). Thread-local `Chain.current` is gone; pass `trace:` into `execute` when needed.
- **ExecutionResult** is what `execute` returns (not `Result`). Use `success?`, `failed?`, `context`, `outcome`, `trace`.
- **Outcome** holds state/status; `success!` / `skip!` / `fail!` still exist on the task and delegate to the session outcome.

## Middleware

Use Rack-style signatures:

```ruby
module MyMw
  def self.call(env, **options)
    yield
  end
end

register :middleware, MyMw, if: :some_predicate?
```

`env` is `CMDx::MiddlewareEnv` (`session`, `handler`).

## Removed or renamed pieces

- `CMDx::Result`, `CMDx::Resolver`, `CMDx::Chain`, `CMDx::Settings`, registry classes, `Attribute`, `AttributeValue`, `Parallelizer`, built-in log formatters.
- `CMDx::Exception` alias removed; use `CMDx::Error`.
- `Definition.for` was renamed to `Definition.fetch` (Ruby 3.4+ reserves `for` syntax in some positions).

## Configuration

`CMDx.configure` still works. Registries are replaced by `config.extensions` (`ExtensionSet`) and per-class `register`. Use `CMDx.reset_configuration!` in tests to isolate state.

## Further reading

- [docs/v2/V1_AUDIT.md](docs/v2/V1_AUDIT.md) — what changed conceptually.
