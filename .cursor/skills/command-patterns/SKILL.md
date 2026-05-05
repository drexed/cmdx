---
name: command-patterns
description: Authors and structures Cursor slash-commands that automate recurring developer and AI-maintenance workflows. Use when creating new command files under .cursor/commands/, adding procedural steps, defining constraints, or optimizing command output tables. Do not use for skill authoring, agent definitions, hook scripts, or application code.
---

# Command Authoring Procedure

Follow these steps to generate a command that adheres to the project's structural conventions and produces deterministic, high-quality agent behavior.

## Step 1: Validate Metadata

1. Choose a **kebab-case** name (1-64 characters, lowercase, numbers, and single hyphens only). The name becomes the filename: `.cursor/commands/<folder>/<name>.md`.
2. Determine the **folder**: `sd/` for software developers, `ai/` for AI tooling. Create new folders only when neither fits.
3. Execute the validation script:
   `python3 scripts/validate-metadata.py --name "<name>" --folder "<folder>"`
4. If the script returns an error, self-correct and re-run until successful.

## Step 2: Draft the Command

Use the template in `assets/COMMAND.template.md` as the starting point. Fill in each section following the conventions below.

### Section: Role

- One sentence, third-person: "You are a senior developer [doing X]."
- Describe the persona, not the task.

### Section: Context

- Background the agent needs before acting.
- Use tables for structured references (severity levels, artifact layers, style rules).
- Include project-specific conventions (commit style, PR template path, tool names).
- Keep under 30 lines; move large reference material to skill files or link to project docs.

### Section: Task

- One sentence stating the goal.
- Followed by a `### Steps` subsection with numbered phases.

### Section: Steps

Each step follows this pattern:

1. **Bold phase name** — One-sentence description of the phase.
   - Bullet list of specific actions.
   - Shell commands in fenced code blocks.
   - Parallel operations explicitly noted: "Run these in parallel:"
   - Conditional logic with bold keywords: "If [condition], [action]. Otherwise, [fallback]."

Apply these conventions:

| Convention | Rule |
|------------|------|
| Gathering info | Always the first step; run independent commands in parallel |
| User prompts | Use "Ask the user for:" or "Prompt the user with:" — list each option with defaults |
| Shell commands | Use fenced `bash` blocks; prefer `gh` CLI for GitHub operations |
| HEREDOC commits | Always use `cat <<'EOF'` pattern for multi-line messages |
| Verification | Always include a final verification step (`git status`, `gh pr view`, etc.) |
| Decision points | Present options to the user; never assume destructive choices |

### Section: Constraints

- Bullet list of "Do **not**" rules.
- Always include applicable safety rules from this canonical set:

| Scope | Standard constraints |
|-------|---------------------|
| Git | Do not modify `git config`; do not force-push; do not skip hooks (`--no-verify`); do not run destructive operations without confirmation |
| GitHub | Do not push to `main`/`master` directly; do not dismiss reviews programmatically |
| Files | Do not modify files outside the command's scope; do not commit secrets |
| General | Do not fabricate data; ask rather than assume when intent is unclear |

- Add command-specific constraints after the standard ones.

### Section: Output

- Always a summary table with `Field | Value` columns.
- Fields should be concise identifiers (e.g., **PR**, **Branch**, **Commit**, **Status**).
- Values use inline code for SHAs, numbers, and branch names.
- Optional: a detail table below the summary for itemized results (comments addressed, files changed, findings).

## Step 3: Review Against Checklist

1. Review the `SKILL.md` for "hallucination gaps" (points where the agent is forced to guess).
2. Verify all file paths are **relative** and use forward slashes (`/`).
3. Cross-reference the final output against `references/checklist.md`.

## Error Handling

- **Validation failure:** If `scripts/validate-metadata.py` fails, fix the flagged field and re-run.
- **Scope ambiguity:** If the command straddles consumers, prefer the primary consumer.
- **Overlapping commands:** Before creating a new command, check existing commands that already cover the workflow. Extend an existing command rather than creating a duplicate.
