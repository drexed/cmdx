# Comparison

## Alternative Frameworks

CMDx stands apart by combining zero external dependencies with production-grade observability and a comprehensive type coercion system—all in a single, cohesive package. While other gems excel in specific areas, CMDx delivers the full stack: structured logging with correlation IDs, automatic runtime metrics, 20+ built-in type coercers, extensible middleware, and fault tolerance patterns—without pulling in a single additional dependency.

| Feature | [CMDx](https://github.com/drexed/cmdx) | [Actor](https://github.com/sunny/actor) | [Interactor](https://github.com/collectiveidea/interactor) | [ActiveInteraction](https://github.com/AaronLasseigne/active_interaction) | [LightService](https://github.com/adomokos/light-service) |
|---------|------|------------|------------|-------------------|--------------|
| Zero dependencies | ✅ | ✅ | ✅ | ❌ | ✅ |
| Typed attributes | ✅ | ✅ | ❌ | ✅ | ❌ |
| Type coercion | ✅ | ❌ | ❌ | ✅ | ❌ |
| Attribute validation | ✅ | ✅ | ❌ | ✅ | ❌ |
| Built-in logging | ✅ | ❌ | ❌ | ❌ | ❌ |
| Correlation IDs | ✅ | ❌ | ❌ | ❌ | ❌ |
| Runtime metrics | ✅ | ❌ | ❌ | ❌ | ❌ |
| Middleware system | ✅ | ❌ | ❌ | ❌ | ✅ |
| Batch execution | ✅ | ✅ | ❌ | ✅ | ❌ |
| Fault tolerance | ✅ | ❌ | ❌ | ❌ | ❌ |
| Lifecycle callbacks | ✅ | ✅ | ✅ | ✅ | ✅ |
| RBS type signatures | ✅ | ❌ | ❌ | ❌ | ❌ |

**Key differentiators:**

- **Observability out of the box** — Structured logging, chain correlation, and runtime metrics are built-in, not bolted on. Trace complex workflows across services without additional instrumentation.

- **Comprehensive type system** — 20+ coercers handle everything from primitives to dates, arrays, and custom types. Validation rules like `numeric`, `format`, and `inclusion` ensure data integrity before execution.

- **Extensible middleware** — Inject cross-cutting concerns (authentication, rate limiting, telemetry) without modifying task logic. Middleware composes cleanly and executes in predictable order.

- **Fault tolerance patterns** — Built-in retry policies with exponential backoff, circuit breakers, and timeout handling. Production-ready resilience without external gems.

- **Framework agnostic** — Works seamlessly with Rails, Hanami, Sinatra, or plain Ruby. No ActiveSupport dependency, no framework lock-in.

## Event Sourcing Replacement

Traditional Event Sourcing architectures impose a significant "complexity tax"—requiring specialized event stores, snapshots, and complex state rehydration logic. CMDx offers a pragmatic alternative: **Log-Based Event Sourcing**.

By ensuring all state changes occur through CMDx tasks, your structured logs become a complete, immutable ledger of system behavior.

- **Audit Trail:** Every execution is automatically logged with its inputs, status, and metadata. This provides a detailed history of *intent* (arguments) and *outcome* (success/failure) without extra coding.

- **Reconstructability** Because commands encapsulate all inputs required for an action, you can reconstruct past system states or replay business logic by inspecting the command history, giving you the traceability of Event Sourcing without the infrastructure overhead.

- **Simplified Architecture** Keep your standard relational database for current state queries (the "Read Model") while using CMDx logs as your historical record (the "Write Model"). This gives you CQRS-like benefits without the complexity of maintaining separate projections.
