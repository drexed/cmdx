# Refresh Hooks

## Role

You are a senior developer maintaining Cursor session and preToolUse hooks that enforce skill-based conventions.

## Context

This project uses two hooks (`.cursor/hooks/`) registered in `.cursor/hooks.json`:

| Hook | Type | Purpose |
|---|---|---|
| `session-start` | `sessionStart` | Injects `<project-conventions>` context with the skill map table so the agent knows which skill to read before editing each file type |
| `conventions-check` | `preToolUse` | Denies `Write`, `StrReplace`, and `EditNotebook` calls when the matching skill has not been read in the current transcript |

Both hooks share the same **file-pattern → skill** mapping. When skills are added, removed, or renamed the hooks drift out of sync.

## Task

Reconcile both hook scripts with the current set of skills in `.cursor/skills/*/SKILL.md`.

### Steps

1. **Discover skills** — List every `SKILL.md` under `.cursor/skills/` and extract each skill's directory name (e.g. `model-patterns`). Ignore `skill-patterns` (meta-skill, not a file-convention skill) and any skill whose `SKILL.md` does not reference a file pattern under `app/`, `lib/`, `db/`, or `spec/`.

2. **Extract current mappings** — Parse the file-pattern → skill entries from both:
   - `session-start`: the markdown table rows inside the `session_context` heredoc
   - `conventions-check`: the `elif`/`if` chain that sets `skill_name`

3. **Diff** — Identify:
   - **Missing** skills that exist on disk but have no mapping in either hook
   - **Stale** mappings that reference skills no longer on disk
   - **Inconsistent** entries where the two hooks disagree on patterns or skill names
   - **Ordering issues** — more specific patterns (e.g. concerns) must appear before their parent patterns (e.g. controllers, models) in both hooks

4. **Determine patterns for new skills** — For any missing skill, derive file patterns by inspecting the skill's `SKILL.md` (look for "Use when" / file-path references) and the actual app directory structure. Follow the existing convention:
   - Ruby files: `app/<layer>/**/*.rb` or `lib/**/*.rb`
   - Specs: `spec/**/*.rb`

5. **Update `session-start`** — Regenerate the markdown table inside the `session_context` heredoc. Preserve the rest of the script (escape function, JSON output, memory paragraph) unchanged.

6. **Update `conventions-check`** — Regenerate the `if`/`elif` chain. Rules:
   - More specific patterns first (concerns before controllers/models, emails before views)
   - Each branch sets `skill_name="<skill-directory-name>"`
   - Use `[[ "$file_path" == */<glob> ]]` patterns matching the existing style
   - Keep the rest of the script (jq parsing, `skill_loaded` function, deny JSON) unchanged

7. **Update `hooks.json`** — If any new hook event types are needed (unlikely), add them. Verify the `matcher` regex on `preToolUse` still covers the tool names used in `conventions-check`.

8. **Verify** — Run both hooks in a dry-run:
   ```bash
   echo '{}' | .cursor/hooks/session-start
   echo '{"tool_name":"Write","tool_input":{"path":"app/models/foo.rb"},"transcript_path":""}' | .cursor/hooks/conventions-check
   ```
   Confirm valid JSON output and no shell errors.

## Constraints

- Do **not** modify skill files — only hook scripts and `hooks.json`
- Do **not** change the hook script structure (argument parsing, JSON output format, `skill_loaded` function)
- Keep both hooks executable (`chmod +x`)
- Keep the `session_context` heredoc's memory paragraph at the end
- Patterns in `conventions-check` must use the same bash glob style (`*/lib/**.rb`) already present
- The markdown table in `session-start` must use the same column format already present
- Run `bundle exec rubocop` is not needed — these are bash scripts, not Ruby

## Output

After updating, list the final skill map as a summary table so the user can verify.
