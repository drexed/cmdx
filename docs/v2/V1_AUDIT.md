# V1 → V2 audit (concepts retained vs dropped)

This document satisfies the v2 plan audit: what v1 provided and what v2 replaces or removes. It is **not** a parity checklist.

## Retained concepts (CERO)

- **Compose**: typed/command objects with declared inputs, optional workflows composing steps.
- **Execute**: single entry (`execute` / `execute!`) returning a rich outcome.
- **React**: predicate API on outcome (`success?`, `failed?`, `skipped?`) and context access.
- **Observe**: trace identifiers, structured telemetry hooks, optional logging.

## Dropped or replaced

| V1 | V2 |
|----|-----|
| `Settings` + five CoW registries | `Definition` + `ExtensionSet` (one merge model) |
| `Result` + `Resolver` + `instance_variable_set` | `Outcome` with explicit transitions |
| `Attribute#task` + dup-per-run | Frozen `AttributeSpec` + `AttributePipeline` |
| `Chain.current` thread/fiber default | `Trace` carried on `Session` (explicit correlation) |
| `CMDx::Exception = Error` | `CMDx::Error` only (no `Exception` alias) |
| Middleware `call(task, **opts, &)` | `call(env, &next)` with `MiddlewareEnv` |
| `Context#method_missing` as default hot path | Hash-backed `Context`; optional accessors |
| `AttributeValue` class | Pipeline stages on `AttributeSpec` |
| Many log formatter classes as core | `Telemetry` / `LogSink` adapter pattern |
| 80+ locale files in core | English defaults in `CMDx::V2::Locale`; optional full locales later |
| `throw(:cmdx_halt)` | `throw(:cmdx_v2_halt)` (internal); documented |

## Optional / deferred

- Full I18n parity for all validator strings (start with English + `I18n.t` when gem present).
- Rack/Rails-specific middleware ports beyond a correlate + runtime example.
- Non-thread parallel backends (protocol only: `Parallel::Backend`).
