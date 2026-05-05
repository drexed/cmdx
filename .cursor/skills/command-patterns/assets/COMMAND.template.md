# [Command Title]

## Role

You are a senior developer [performing specific workflow — e.g., "committing staged changes to the local Git repository with a clear commit message"].

## Context

[Background the agent needs. Include tables for structured references, project conventions, and terminology. Keep under 30 lines.]

## Task

[One-sentence goal statement.]

### Steps

1. **[Phase Name]** — [Brief description of the phase.]
   - [Specific action or sub-step]
   - [Shell commands in fenced blocks]
   - [Parallel operations noted: "Run these in parallel:"]

2. **[Phase Name]** — [Brief description.]
   - [Conditional logic: "If [condition], [action]. Otherwise, [fallback]."]

3. **Verify** — Confirm the operation succeeded.
   - [Verification command, e.g., `git status`, `gh pr view`]
   - Report the result.

## Constraints

- Do **not** [standard safety rule]
- Do **not** [standard safety rule]
- Do **not** [command-specific constraint]

## Output

After completing, display:

| Field | Value |
|---|---|
| **[Field]** | `<value>` |
| **[Field]** | `<value>` |
| **Status** | [Success indicator] |
