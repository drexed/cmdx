# CMDx roadmap (ideas)

Items here are **exploratory roadmap ideas**, not shipped features or release commitments. Names, APIs, and layering may change as designs are validated against real apps and benchmarks.

Use this file to track **what we might build next** and **why**. When work starts on an item, link a design note or issue and move status toward *in progress* / *done* in the changelog instead of treating this doc as the source of truth for behavior.

---

## Infrastructure primitives

### Serializers (`config.serializers` + registry)

**Status:** Idea (foundational — intended before or alongside cache and checkpoint)  
**Theme:** One generic encode/decode layer for anything that persists Ruby-ish data through `CMDx::Stores` or job payloads.

#### Problem

`CMDx::Stores` only speaks **strings** (see [Stores](docs/stores.md)). Features that need to round-trip structured state—workflow checkpoints, cached task outputs, large context snapshots—must agree on:

- **Format** (JSON, MessagePack, compressed JSON, app-specific encryption),
- **Versioning** (blob schema when task classes or context keys change),
- **Safety** (what types may appear in a payload; no accidental `Marshal` of arbitrary objects),
- **Failure modes** (corrupt blob, unknown serializer id, decode errors).

Today, `Context#to_json` and `Result#to_h` help with logging and introspection, but they are not a **contract** for store-backed persistence. Cache and checkpoint would otherwise each invent their own envelope and error types.

#### Intended function

A small **serializer framework** parallel to existing registries (`coercions`, `validators`, `executors`, `mergers`):

1. **Global config** — `CMDx.configure { |c| c.serializers = … }` with a default registry instance (and `CMDx.reset_configuration!` restores it in tests, same hierarchy rules as other registries).
2. **Registry** — `CMDx::Serializers` (name TBD) maps **symbols** to serializer objects that implement a narrow contract, e.g. `#dump(object) → String` and `#load(string) → object` (exact names aligned with Ruby conventions).
3. **Built-ins** — at minimum a **JSON** serializer that produces UTF-8 strings safe for Redis/memory adapters; optional built-ins (e.g. compressed JSON, MessagePack) only if they stay stdlib/light-deps friendly or live behind optional requires.
4. **Registration** — `CMDx.serializers.register :my_app, MySerializer` or `config.serializers.register(...)` so apps can plug encryption, Avro, or “store id in SQL, blob in S3” wrappers without forking core.
5. **Envelope** — higher-level helpers (not necessarily exposed to every user) wrap domain objects in a **versioned document**, e.g. serializer id, format version, task/workflow identity, payload — so cache and checkpoint share one on-the-wire shape and telemetry can record `serializer:` and `bytes:`.
6. **Resolution order** — feature-level option → task/workflow `settings` → global default (same layering story as loggers and middlewares).
7. **Explicit boundaries** — serializers used for **persistence** should default to **JSON-safe** data (Hash-like structures with string keys, scalars, arrays); opt-in hooks for types that implement a CMDx protocol (e.g. `#as_cmdx_payload` / `.from_cmdx_payload`) instead of implicit `as_json` on every value.

#### Proposed API (sketch)

```ruby
# config/initializers/cmdx.rb
CMDx.configure do |config|
  config.serializers = CMDx::Serializers.new
  config.serializers.register :json, CMDx::Serializers::JSON.new
  config.serializers.register :encrypted_json, MyApp::EncryptedJsonSerializer.new
  config.default_serializer = :json
end

# Lookup
blob = CMDx.serializers[:json].dump({ "v" => 1, "outputs" => { "rate" => "1.02" } })
data = CMDx.serializers[:json].load(blob)

# Feature override (cache / checkpoint / future store features)
class FetchExchangeRate < ApplicationTask
  cache_result key: :pair, ttl: 300, serializer: :json
end

class FulfillmentWorkflow < CMDx::Task
  include CMDx::Workflow
  settings checkpoint_serializer: :encrypted_json
end
```

#### Design notes

- **Not idempotency values:** Idempotency store entries (`processing` / `completed`) stay tiny opaque strings; serializers target **payload blobs**, not lease tokens.
- **Size limits:** Registry or envelope may expose `max_bytes` / compression hints; adapters can refuse writes before hitting Redis limits.
- **Corruption:** `#load` raises a dedicated error (subclass of `CMDx::Error` or similar) so cache/checkpoint can treat decode failure as a **miss** or **resume from scratch**, with telemetry `:serializer_decode_failed`.
- **Testing:** In-memory store + round-trip helpers in spec support (`dump_load_roundtrip`) keep features from re-testing JSON edge cases.
- **Job adapters:** The same registry can validate enqueue payloads (`serializers[:json].dump(context_hash)` must succeed) so background-job and store features share one definition of “serializable context.”

#### Open questions

- Single `CMDx::Serializers::JSON` vs reusing `Context#to_json` / custom key normalization (symbols → strings)?
- Built-in **allowlist** of context keys per task (`persist: %i[rate user_id]`) enforced at dump time?
- Whether envelope lives in **core** or in a `CMDx::Persistence::Envelope` module shared by cache/checkpoint only?
- Compression as a serializer decorator vs separate `:gzip_json` registration?

#### Related

- [Configuration](docs/configuration.md) — pattern for global registries  
- [Stores](docs/stores.md) — string values, TTL  
- `CMDx::Context#to_json`, `CMDx::Result#to_h` — logging/introspection, not persistence contract  
- `cache_result` and **Checkpoint / resume** (below) — primary consumers

---

### `CMDx::Cache` / `cache_result`

**Status:** Idea  
**Theme:** Cross-process memoization of successful task runs (read-through cache), distinct from idempotency.

#### Problem

Many tasks are **pure or expensive-but-deterministic** for a given input set: geocoding, FX rates, permission snapshots, third-party “get user” calls. Today you either:

- Recompute on every `execute`, or
- Hand-roll caching in `#work` with Redis/Memcached and inconsistent key/TTL/error semantics.

`idempotent_by` solves **duplicate side effects** (at-most-once *execution*), not **reuse of a prior successful result** when you are happy to skip `work` entirely and return stored outputs.

#### Intended function

A declarative helper (working name `cache_result`, backed by something like `CMDx::Cache`) that:

1. Runs **after** input resolution (same general placement as idempotency/locks in `Runtime`) so keys are built from validated, coerced inputs and context.
2. Computes a **stable cache key** from the task class and a user-defined segment (symbol on context, proc, etc.—same ergonomics as `idempotent_by` / `lock_with`).
3. On **cache hit** with a valid, non-expired entry: short-circuit before `#work`, hydrate `context` / declared **outputs** from the stored payload, and finish with a successful result (telemetry should distinguish *cached* vs *executed*).
4. On **miss**: run the normal lifecycle (`work`, output verification, etc.). On **success only**, **dump** a snapshot of the return surface (outputs and any agreed context keys) through the configured **serializer** into `CMDx::Stores` with a TTL.
5. On **failure** (`fail!`, `skip!`, raised errors): do **not** write or refresh the cache entry (failed runs must not poison the cache).

#### Proposed API (sketch)

```ruby
class FetchExchangeRate < ApplicationTask
  cache_result key: ->(t) { "#{t.base_currency}:#{t.quote_currency}:#{t.as_of}" },
               ttl: 300,
               namespace: "cmdx:cache",
               serializer: :json

  required :base_currency, :quote_currency
  required :as_of, coerce: :date

  output :rate

  def work
    context.rate = ExternalRates.fetch(base_currency, quote_currency, as_of)
  end
end
```

#### Design notes

- **Shared store layer:** Reuse `CMDx::Stores` (Redis/Memory adapters, TTL, namespacing) so cache entries behave like idempotency and circuit-breaker keys in multi-worker deployments.
- **Similar machinery to checkpoint (below):** Key composition, TTL, conditional writes, and telemetry hooks should follow the same patterns as `Idempotency` and `Lock`—one implementation style for “store-backed runtime primitives.”
- **Serializers registry:** Use `config.serializers` (see above) for dump/load; cache owns *what* to persist (outputs, optional context keys), not *how* to encode bytes.
- Must respect `output` declarations and avoid caching secrets unless the app opts in (`serializer:` / allowlists).
- **Interaction with `idempotent_by`:** A duplicate *invocation* might still be an idempotency skip while cache is a separate concern; ordering in `Runtime` and docs need to spell out combined behavior (e.g. idempotency claim first, then cache read inside the claim).

#### Open questions

- Cache **invalidation** API (manual `del`, version in key, `if:` / `unless:` gates)?
- Should cache hits **run callbacks** (`on_executed`, telemetry subscribers) or a lighter “cache_hit” event only?
- Stale-while-revalidate or single-flight deduplication under load?

#### Related

- [Stores](docs/stores.md) — planned home for cache and checkpoint bytes  
- [Idempotency](docs/idempotency.md) — duplicate execution, not result reuse  
- `CMDx::Idempotency` — reference for store key layout and `Runtime` wrapping  
- **Serializers** (above) — shared encode/decode for cache entries

---

## Tasks

### `execute_async` (non-blocking execution)

**Status:** Idea  
**Theme:** Run a task without blocking the caller; observe completion via a future-like handle.

#### Problem

`Task.execute` / `execute!` are **synchronous**: the caller blocks until `Runtime` finishes, including retries, locks, and parallel workflow children. That is correct for HTTP requests and scripts, but awkward when you want to:

- Kick off work and continue in the same process (UI thread, event loop, `Async` integration),
- Compose multiple tasks concurrently without manually managing threads/fibers,
- Attach timeouts or cancellation at the call site without pushing that into every task.

Apps today wrap `execute` in `Thread.new`, custom executors, or job queues—losing consistent telemetry, chain semantics, and error surfaces.

#### Intended function

An async entry point (name TBD, e.g. `execute_async`) that:

1. Schedules the same **full** `Runtime` lifecycle on a configurable executor (thread pool, fiber scheduler, or injected backend).
2. Returns immediately with a **future-like object** that can:
   - Block with `value` / `wait` (raising under `execute!`-equivalent strictness),
   - Poll `ready?` / `failed?`,
   - Expose the frozen `CMDx::Result` when complete,
   - Optionally propagate **correlation** into the child execution’s chain/telemetry.
3. Preserves existing semantics: middlewares, callbacks, idempotency, locks, circuit breaker, and output verification run unchanged inside the async run.
4. Documents interaction with **fiber-local** `Chain` (child run should not corrupt the parent’s chain; likely a fresh chain root unless explicitly linked).

#### Proposed API (sketch)

```ruby
future = ProcessUpload.execute_async(file_id: upload.id)
# ... do other work ...
result = future.wait          # blocks
result = future.wait(timeout: 5) # TBD

ProcessUpload.execute_async(file_id: upload.id).then { |r| notify(r) } # TBD callback style
```

#### Design notes

- Not a replacement for **distributed** background jobs (see next section); optimized for **in-process** concurrency and testability.
- Strict vs non-strict should mirror `execute` / `execute!` on the future.
- Error objects raised on `wait` should match today’s `Fault` / exception story.

#### Open questions

- Default executor vs explicit `executor:` on each call vs global config?
- Cancellation API (kill thread vs cooperative cancel token into `work`)?
- Integration with workflow `:parallel` groups—shared pool or separate?

#### Related

- `CMDx::Runtime` — lifecycle to schedule unchanged  
- [Workflows – parallel groups](docs/workflows.md) — existing in-pipeline concurrency  
- Blog: [Background Jobs + CMDx](docs/blog/posts/real-world-cmdx-background-jobs.md) — when async leaves the process

---

### Background-job adapter (`perform_async` / `perform_in` / `perform_at`)

**Status:** Idea  
**Theme:** First-class enqueue helpers for Sidekiq, ActiveJob, GoodJob, etc., with safe serialization at the boundary.

#### Problem

Production apps almost always run CMDx at the **edge of a job runner**. The recommended pattern today is a thin job class that calls `execute!`—which works but duplicates boilerplate across apps:

- JSON-safe argument hashes (string keys),
- Correlation id handoff across processes,
- Mapping permanent `fail!` outcomes to “do not retry” vs transient errors,
- Optional `idempotent_by` keys derived from job arguments.

Self-including `Sidekiq::Job` on the task class (documented in the blog) blurs “domain task” and “infrastructure adapter” and makes testing/no-Sidekiq environments heavier.

#### Intended function

Optional adapter layer (per backend or a small family of modules) that:

1. Exposes familiar enqueue methods on the task class, e.g. `perform_async`, `perform_in`, `perform_at` (exact names aligned with the target gem where possible).
2. At **enqueue time**, validates that the payload round-trips through the configured **serializer** (default `:json`): attribute keys, primitive types, no live objects. Fail fast in development if someone passes an `ActiveRecord` instance.
3. At **perform time**, rebuilds context from the payload and calls `execute` / `execute!` with documented retry behavior hooks (e.g. register which `metadata[:code]` values are permanent).
4. Supports **correlation id** propagation via an optional key in the payload and a documented callback or `settings` hook so telemetry lines up across web → job → nested job.
5. Stays **optional**: no Sidekiq gem required in core; adapters live in optional requires or companion gems if needed.

#### Proposed API (sketch)

```ruby
class Users::SendVerification < ApplicationTask
  include CMDx::Adapters::Sidekiq # name TBD

  sidekiq_options queue: :mailers, retry: 5
  idempotent_by :user_id

  required :user_id, coerce: :integer

  def work
    # ...
  end
end

Users::SendVerification.perform_async(user_id: 42)
Users::SendVerification.perform_in(5.minutes, user_id: 42)
```

#### Design notes

- Enqueue surface should mirror what teams already know from Sidekiq/ActiveJob to reduce migration friction.
- Document pairing with `idempotent_by` and `lock_with` for redelivered messages and concurrent workers.
- ActiveJob wrapper might be a generator template first, then a shared module.

#### Open questions

- One meta-adapter vs per-framework gems?
- Built-in mapping from `CMDx::Fault` / `metadata[:code]` to “discard” vs “retry” without per-app `rescue`?
- Workflow steps that enqueue child jobs—official pattern vs app responsibility?

#### Related

- [Background Jobs + CMDx](docs/blog/posts/real-world-cmdx-background-jobs.md)  
- [Idempotency](docs/idempotency.md), [Locks](docs/locks.md)  
- [Stores](docs/stores.md) — shared state across workers  
- **Serializers** (above) — shared definition of serializable job/context payloads

---

## Workflows

### Checkpoint / resume

**Status:** Idea  
**Theme:** Persist workflow progress so a restarted run can skip completed step groups.

#### Problem

Long-running workflows (onboarding, fulfillment, provisioning) often span **multiple processes** or survive **worker crashes**. Today a workflow is a single `Pipeline` run on one context in one process:

- If the process dies after step 3 of 5, a retry typically **re-runs from the start** unless the app manually tracks state in the database.
- Parallel groups and rollback semantics make ad hoc “save state in `#work`” easy to get wrong.

#### Intended function

Checkpointing that:

1. Identifies the workflow run with a stable **run id** (from context, `idempotent_by`, or explicit `checkpoint_by`—design TBD).
2. After each **execution group** completes successfully (respecting `if:` / `unless:` skips), **dumps** a versioned snapshot of workflow `context` (plus resume metadata: completed group ids, skip/fail markers) via the **serializers registry** into `CMDx::Stores` or a pluggable backend.
3. On a subsequent `execute` with the same run id, **loads** the blob through the same serializer (or fails gracefully if the format is unknown/corrupt), **hydrates** context, and **skips** groups already marked complete, then continues from the next pending group.
4. Handles **failure** without advancing the checkpoint; failed groups remain retryable.
5. Defines behavior for **parallel groups** (checkpoint only after merger succeeds), **conditional groups** (record skipped vs completed distinctly), and **rollback** (whether checkpoint is cleared or branched).

#### Proposed API (sketch)

```ruby
class FulfillmentWorkflow < ApplicationTask
  include CMDx::Workflow

  idempotent_by :order_id # natural pairing: same order → same logical run

  checkpoint true # or checkpoint_by: :order_id, ttl: 1.day, serializer: :json

  task ValidateOrder
  task ReserveInventory
  tasks ChargePayment, CreateShipmentLabel, strategy: :parallel
  task NotifyCustomer
end
```

#### Design notes

- **Pairs with `idempotent_by`:** Duplicate job delivery can resume the same checkpointed run instead of duplicating side effects; docs should show recommended key shapes.
- **Serializers registry:** Checkpoint blobs use the same envelope as cache (serializer id + version); large payloads may use a custom registered serializer (compression, external blob pointer).
- **Store size and TTL:** Allowlists of persistable context keys enforced at dump time; core may store pointers when the serializer returns a short reference string.
- **Security:** Checkpoint blobs may contain PII; encryption and namespace isolation are app concerns but the API should not surprise authors.
- **Observability:** Telemetry events for checkpoint write, resume, and skip-per-group aid debugging stuck workflows.

#### Open questions

- Opt-in per workflow vs per-group `checkpoint: false` for sensitive steps?
- Migration when task classes change (envelope `format_version` vs per-workflow `checkpoint_version`)?
- Interaction with saga **rollback**—truncate checkpoint or fork a new run?

#### Related

- [Workflows](docs/workflows.md) — execution groups and pipeline  
- [Stores](docs/stores.md) — “(eventually) workflow checkpoints”  
- `CMDx::Pipeline` — group boundaries for persistence hooks  
- `cache_result` (above) — shared store primitive patterns  
- **Serializers** (above) — dump/load contract for checkpoint blobs

---

## How to contribute to this list

1. Add or refine a section with **problem**, **intended function**, and **open questions**—not only a one-line bullet.  
2. When prototyping, add a link to a PR or discussion at the top of that section.  
3. Ship user-facing behavior through **docs + CHANGELOG**; trim or archive roadmap text here once the feature is released.
