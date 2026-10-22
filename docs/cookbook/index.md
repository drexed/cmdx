# Cookbook

Real apps do not stop at “define a task and call `work`.” They need jobs, databases, auth, rate limits, and traces that make sense at 2 a.m.

These recipes are copy-paste starting points for wiring CMDx into a Rails app. Each page stands on its own — open the one closest to what you are building today.

### How each recipe is laid out

Most pages follow the same rhythm so you can skim:

1. **Intro** — what problem this solves and when to reach for it
2. **Setup** — middleware, initializer, or helper you install once
3. **Usage** — register it on a task and run an example
4. **What to expect** — sample SQL, JSON, or `Result` shapes (when it helps)
5. **Notes** — gotchas and “pick this vs that” tips

## Rails and Active Record

- [Active Record Database Transaction](active_record_database_transaction.md) — commit every write together, or roll back as a unit
- [Active Record Query Tagging](active_record_query_tagging.md) — stamp SQL with the task name and trace ids
- [Paper Trail Whatdunnit](paper_trail_whatdunnit.md) — tell Paper Trail *which task* changed a record

## API and integration

- [GraphQL Resolvers](graphql_resolvers.md) — keep mutations thin; let tasks do the work
- [OpenAPI Schema Generation](openapi_schema_generation.md) — generate request schemas from task inputs
- [PubSub Task Chaining](pub_sub_task_chaining.md) — trigger follow-on work with domain events

## Cross-cutting concerns

- [Background Execution](background_execution.md) — run tasks on a queue with Active Job or Sidekiq
- [Store Wrappers](store_wrappers.md) — test doubles and instrumented store wrappers
- [Flipper Feature Flags](flipper_feature_flags.md) — gate tasks behind feature flags
- [Pundit Authorization](pundit_authorization.md) — authorize before `work` runs
- [Rate Limit](rate_limit.md) — throttle hot endpoints with `CMDx::Stores`
- [Timeout Guard](timeout_guard.md) — cap how long a task may run
- [Sentry Error Tracking](sentry_error_tracking.md) — send failures to Sentry with context
- [OpenTelemetry Tracing](opentelemetry_tracing.md) — one span per task, nested like your chain
