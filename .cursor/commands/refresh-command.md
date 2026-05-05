# Refresh Commands

## Role

You are a senior developer maintaining Cursor slash-commands that automate recurring maintenance workflows for the project's AI tooling layer.

## Context

This project uses custom commands (`.cursor/commands/*.md`) that encode multi-step maintenance procedures. Each command references project artifacts that evolve independently:

| Artifact Layer | Location | What Commands Reference |
|---|---|---|
| Skills | `.cursor/skills/*/SKILL.md` | Skill directory names, file-pattern mappings, dependency ordering, directory scopes |
| Agents | `.cursor/agents/*.md` | Agent file names, front-matter fields, source-of-truth file lists |
| Hooks | `.cursor/hooks/*`, `.cursor/hooks.json` | Hook names, event types, matcher regex, skill-map tables |
| Rules | `.cursor/rules/*.mdc` | Instruction file names, technology versions, architecture references |
| Commands | `.cursor/commands/*.md` | Cross-references to other commands, shared terminology, structural conventions |

When any of these sources change — skills added or removed, agents created, hooks restructured, rules updated, or new commands introduced — existing commands drift and produce incomplete or incorrect guidance.

## Task

Refresh one or more command definitions so they accurately reflect the current project state.

The user will specify which command(s) to refresh (e.g. `refresh-hook`, `refresh-skill`), or say "all" for a full sweep.

### Steps

1. **Discover commands** — List every `.md` under `.cursor/commands/`. Parse each command's title, role, referenced artifacts, and procedural steps. Skip `refresh-command.md` itself unless the user explicitly includes it.

2. **Gather current project state** — Collect the ground-truth for every artifact layer commands depend on:
   - **Skills**: list `.cursor/skills/*/SKILL.md` — extract directory names and file-pattern scopes from each SKILL.md's description and "Use when" triggers
   - **Agents**: list `.cursor/agents/*.md` — extract front-matter fields (`name`, `description`, `tools`)
   - **Hooks**: read `.cursor/hooks.json` and each hook script — extract event types, matchers, and the file-pattern → skill mapping
   - **Rules**: list `.cursor/rules/*.mdc` — extract instruction file names and any version references from `.cursor/rules/cursor.instructions.mdc`
   - **Commands**: list `.cursor/commands/*.md` — note cross-references between commands

3. **Diff each command vs ground-truth** — For each in-scope command, identify:
   - **Stale references** — artifact names, file paths, or directory patterns that no longer exist or have been renamed
   - **Missing artifacts** — new skills, agents, hooks, rules, or commands that the command's procedure should cover but doesn't
   - **Incorrect enumerations** — steps that list specific items (skills, agents, file patterns, source files, dependency ordering) where the list is now incomplete or has extra entries
   - **Structural drift** — step sequences that no longer match the current artifact structure (e.g. a step referencing `hooks.json` fields that changed, or a verification command that needs updating)
   - **Terminology drift** — mismatched names between what the command says and what the artifacts are actually called
   - **Cross-command inconsistencies** — two commands describing the same artifact differently

4. **Update each command** — Apply targeted edits:
   - Update artifact references (file paths, directory names, skill names, agent names)
   - Update enumerated lists and tables to match current ground-truth
   - Update step sequences where the underlying artifact structure changed
   - Add steps for new artifact types or categories the command should handle
   - Remove steps for artifacts that no longer exist
   - Do **not** rewrite sections that are still accurate — make surgical edits
   - Preserve each command's voice, structural layout, and section ordering

5. **Validate** — After updating each command:
   - Confirm every file path or glob pattern referenced in the command resolves to an existing artifact
   - Confirm every skill, agent, hook, or rule name referenced in the command matches an actual artifact on disk
   - Confirm enumerated lists (skill dependency orders, file-pattern tables, source-file lists) are complete — no missing or extra entries
   - Confirm any shell commands in verification steps are syntactically valid
   - Confirm cross-references between commands are consistent

## Constraints

- Do **not** modify application code, skills, agents, hooks, or rules — only command files under `.cursor/commands/`
- Do **not** change a command's purpose, role definition, or structural layout — only update factual content
- Do **not** create new command files — only refresh existing ones
- Do **not** delete commands — flag obsolete ones for the user to decide
- Preserve the existing section ordering, markdown formatting style, and heading hierarchy of each command
- When a command enumerates skills in a specific order (e.g. dependency order), verify and correct the ordering based on actual inter-skill dependencies
- When a command references verification shell commands, ensure they match the current hook/script interfaces

## Output

After refreshing, provide a summary table:

| Command | Changes | Status |
|---|---|---|
| `refresh-hook` | Updated skill list, added new hook event type reference | ✅ Updated |
| `refresh-skill` | No changes needed | ⏭️ Skipped |
| `refresh-agent` | Removed reference to deleted agent, updated source file list | ✅ Updated |
