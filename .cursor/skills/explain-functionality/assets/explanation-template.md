# Explanation: `[method/class name]`

**File:** `[file path]` | **Lines:** [start]–[end]

> [One-sentence summary: what this code does and why, in domain terms.]

## 1. Structure

- **Entry:** [what triggers this code]
- **Flow:** [internal call sequence]
- **Exit:** [return values, signals, mutations]
- **Branches:** [conditions that diverge flow]

## 2. Data Flow

**Inputs:**
| Name | Source | Type / Shape |
|------|--------|-------------|
| ... | ... | ... |

**Transformation:**
```
input → step_1 → step_2 → output
     ↘ fail! on [condition]
```

**Outputs:**
| Name | Destination | Type / Shape |
|------|-------------|-------------|
| ... | ... | ... |

## 3. Dependencies

| Dependency | Direction | Coupling | Failure Mode |
|------------|-----------|----------|-------------|
| ... | upstream/downstream/lateral | hard/soft | ... |

## 4. Side Effects

| Effect | Category | When | Reversible? | Idempotent? |
|--------|----------|------|-------------|-------------|
| ... | ... | ... | ... | ... |

## 5. Intent & Rationale

[Why this code exists. Why this approach over alternatives. Non-obvious choices. Domain semantics.]

## 6. Edge Cases & Assumptions

| Assumption | Guarded? | Risk if Violated |
|------------|----------|------------------|
| ... | ... | ... |

## 7. Quick Reference

| Item | Value |
|---|---|
| Entry point | ... |
| Key classes | ... |
| Side effects | ... |
