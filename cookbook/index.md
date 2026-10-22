# Cookbook

Real apps do not stop at “define a task and call `work`.” They need jobs, databases, auth, rate limits, and traces that make sense at 2 a.m.

These recipes are copy-paste starting points for wiring CMDx into a Rails app. Each page stands on its own — open the one closest to what you are building today.

### How each recipe is laid out

Most pages follow the same rhythm so you can skim:

1. **Intro** — what problem this solves and when to reach for it
1. **Setup** — middleware, initializer, or helper you install once
1. **Usage** — register it on a task and run an example
1. **What to expect** — sample SQL, JSON, or `Result` shapes (when it helps)
1. **Notes** — gotchas and “pick this vs that” tips

## Rails and Active Record

- [Active Record Database Transaction](https://drexed.github.io/cmdx/cookbook/active_record_database_transaction/index.md) — commit every write together, or roll back as a unit
- [Active Record Query Tagging](https://drexed.github.io/cmdx/cookbook/active_record_query_tagging/index.md) — stamp SQL with the task name and trace ids
- [Paper Trail Whatdunnit](https://drexed.github.io/cmdx/cookbook/paper_trail_whatdunnit/index.md) — tell Paper Trail *which task* changed a record

## API and integration

- [GraphQL Resolvers](https://drexed.github.io/cmdx/cookbook/graphql_resolvers/index.md) — keep mutations thin; let tasks do the work
- [OpenAPI Schema Generation](https://drexed.github.io/cmdx/cookbook/openapi_schema_generation/index.md) — generate request schemas from task inputs
- [PubSub Task Chaining](https://drexed.github.io/cmdx/cookbook/pub_sub_task_chaining/index.md) — trigger follow-on work with domain events

## Cross-cutting concerns

- [Background Execution](https://drexed.github.io/cmdx/cookbook/background_execution/index.md) — run tasks on a queue with Active Job or Sidekiq
- [Store Wrappers](https://drexed.github.io/cmdx/cookbook/store_wrappers/index.md) — test doubles and instrumented store wrappers
- [Flipper Feature Flags](https://drexed.github.io/cmdx/cookbook/flipper_feature_flags/index.md) — gate tasks behind feature flags
- [Pundit Authorization](https://drexed.github.io/cmdx/cookbook/pundit_authorization/index.md) — authorize before `work` runs
- [Timeout Guard](https://drexed.github.io/cmdx/cookbook/timeout_guard/index.md) — cap how long a task may run
- [Sentry Error Tracking](https://drexed.github.io/cmdx/cookbook/sentry_error_tracking/index.md) — send failures to Sentry with context
- [OpenTelemetry Tracing](https://drexed.github.io/cmdx/cookbook/opentelemetry_tracing/index.md) — one span per task, nested like your chain
