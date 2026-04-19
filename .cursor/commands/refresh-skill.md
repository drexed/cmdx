# Refresh Skill

## Role

You are a senior developer maintaining agent skills that document codebase conventions and serve as procedural guides for AI-assisted development.

## Context

This project (CMDx) is a Ruby gem providing a framework for designing and executing complex business logic within service/command objects. It uses pattern-based skills (`.cursor/skills/*/SKILL.md`) that encode conventions extracted from actual implementations. Each skill has:

- **`SKILL.md`** — YAML front-matter (`name`, `description`) + procedural instructions with architecture overviews, step-by-step procedures, code skeletons, and constraint lists
- **`references/checklist.md`** — validation checklist customized to the skill's domain conventions
- Optional `references/`, `scripts/`, `assets/` subdirectories

Skills drift when the codebase evolves: new files are added, patterns change, conventions are refined, method signatures shift, or entire modules are introduced or removed. A stale skill produces wrong or incomplete guidance.

## Task

Refresh one or more skills so they accurately reflect the current codebase.

The user will specify which skill(s) to refresh (e.g. `issue-debugging`, `performance-optimizations`), or say "all" for a full sweep. When "all" is requested, process skills in dependency order: skill-patterns → command-patterns → performance-optimizations → issue-debugging → explain-functionality.

### Steps

1. **Read the skill** — Read the target `SKILL.md` and its `references/` files to understand the current documented state.

2. **Audit the codebase layer** — Scan the corresponding source directories for every file the skill covers:
   - For `performance-optimizations`: `lib/cmdx/**/*.rb`, `.cursor/skills/performance-optimizations/scripts/*.rb`
   - For `issue-debugging`: `lib/cmdx/**/*.rb`, `spec/**/*.rb`
   - For `explain-functionality`: `lib/cmdx/**/*.rb`, `lib/cmdx.rb` (covers all framework source)
   - For `command-patterns`: `.cursor/commands/**/*.md`
   - For `skill-patterns`: `.cursor/skills/*/SKILL.md`, `.cursor/skills/*/references/*.md`

3. **Diff documented vs actual** — For each skill, identify:
   - **New implementations** not mentioned in the skill (new files, classes, modules, public API methods, signal types, exception classes, etc.)
   - **Removed implementations** documented but no longer in the codebase
   - **Changed patterns** where the code has diverged from the documented convention (renamed methods, new base class behavior, different method signatures, new module inclusions)
   - **Stale counts or tables** where inventory numbers or examples are wrong
   - **Missing procedures** for patterns that now exist but have no step-by-step guidance

4. **Update `references/checklist.md`** — Sync the checklist with current conventions:
   - Add items for new conventions or patterns discovered during audit
   - Remove items for conventions that no longer apply
   - Update item descriptions where the convention has changed (e.g. renamed methods, new options, different ordering)
   - Do **not** rewrite items that are still accurate — make surgical edits
   - Preserve the existing section structure and `- [ ]` format

5. **Update topic-specific reference files** — For each additional `references/*.md` file beyond `checklist.md` (e.g. `ruby-optimizations.md`):
   - Re-scan the codebase sections the file covers
   - Add entries for new implementations, patterns, or examples discovered during the audit
   - Remove entries for implementations that no longer exist
   - Update code snippets, tables, groupings, and descriptions where the code has diverged
   - Do **not** rewrite sections that are still accurate — make surgical edits
   - Preserve the existing formatting style and section structure of each file

6. **Update `SKILL.md`** — Apply targeted edits:
   - **Front-matter `description`**: update if trigger words, negative triggers, or CMDx module references changed
   - **Architecture Overview**: update module counts, class inventories, method signature tables, and inheritance chains
   - **Procedures**: add steps for new patterns; remove steps for deleted patterns; adjust existing steps where conventions changed
   - **Code skeletons**: update to reflect current `CMDx::Task` behavior, `CMDx::Context` API, `CMDx::Result` states, `CMDx::Runtime` methods, exception classes, and signal types
   - **Constraint lists**: add/remove rules based on what the codebase now enforces
   - Do **not** rewrite sections that are still accurate — make surgical edits
   - Keep total `SKILL.md` under 500 lines; move overflow to `references/`

7. **Cross-reference other skills** — If the refresh reveals changes that affect other skills (e.g. a new exception class should be mentioned in `issue-debugging`), note them but do **not** edit other skills unless they are also in the refresh scope.

8. **Validate** — After updating:
   - Confirm the YAML front-matter parses correctly (name 1-64 chars, description ≤ 1024 chars)
   - Confirm all file paths in the skill are relative and use forward slashes
   - Confirm code skeletons match actual class/module signatures (spot-check 2-3 files in `lib/cmdx/`)
   - Confirm `references/checklist.md` items align with the procedures in `SKILL.md` — no checklist item references a convention that is not documented, and no documented convention is missing from the checklist

## Constraints

- Do **not** modify application code — only skill files under `.cursor/skills/`
- Do **not** create new skill directories — only refresh existing ones
- Do **not** delete skills — flag obsolete ones for the user to decide
- Preserve the existing section ordering and formatting style of each skill
- Keep `SKILL.md` under 500 lines; extract to `references/` if needed
- Write in **third-person imperative** ("Create the task", not "You should create")
- When reading large directories, sample representative files rather than reading every line of every file — focus on structure, not business logic

## Output

After refreshing, provide a summary table:

| Skill | Changes | Status |
|---|---|---|
| `performance-optimizations` | Updated benchmark script references, added new `Runtime` method | ✅ Updated |
| `issue-debugging` | Added new exception class, updated signal types | ✅ Updated |
| `explain-functionality` | No changes needed | ⏭️ Skipped |
