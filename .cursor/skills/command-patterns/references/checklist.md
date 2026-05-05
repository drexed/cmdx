# Command Validation Checklist

Use this checklist to perform a final audit of a generated command before deployment. Every item must be marked as "Pass" to ensure the command is well-structured, safe, and deterministic.

## 1. Metadata & Placement

- [ ] **Naming:** The filename is kebab-case, 1-64 characters, lowercase letters, numbers, and single hyphens only.
- [ ] **Folder:** Placed in the correct folder — `sd/` for software developers, `ai/` for AI tooling.
- [ ] **No Duplicates:** No existing command already covers the same workflow (check `.cursor/commands/`).

## 2. Section Hierarchy

- [ ] **Role:** Present, one sentence, third-person ("You are a senior developer [doing X].").
- [ ] **Context:** Present, under 30 lines, includes tables for structured references where applicable.
- [ ] **Task:** Present, one-sentence goal statement followed by a `### Steps` subsection.
- [ ] **Constraints:** Present, bullet list of "Do **not**" rules.
- [ ] **Output:** Present, summary table with `Field | Value` columns.
- [ ] **No Extra Sections:** Only the five standard sections appear (Role, Context, Task, Constraints, Output).

## 3. Steps Quality

- [ ] **Numbered Phases:** Steps are numbered with **bold phase names** and a dash separator.
- [ ] **Parallel Gather:** First step collects independent information with "Run these in parallel:" when multiple commands are needed.
- [ ] **User Prompts:** User input requests use "Ask the user for:" with listed options and defaults.
- [ ] **Shell Commands:** All shell commands appear in fenced `bash` blocks.
- [ ] **HEREDOC Pattern:** Multi-line Git/CLI messages use `cat <<'EOF'` syntax.
- [ ] **Conditional Logic:** Decision points use bold keywords — "If [condition], [action]. Otherwise, [fallback]."
- [ ] **Verification:** Final step confirms success with a verification command (`git status`, `gh pr view`, etc.).

## 4. Constraints & Safety

- [ ] **Git Safety:** Includes applicable rules — no `git config` changes, no force-push, no `--no-verify`, no destructive ops without confirmation.
- [ ] **GitHub Safety:** Includes applicable rules — no direct push to `main`/`master`, no programmatic review dismissal.
- [ ] **File Safety:** Includes applicable rules — no modifications outside scope, no secret commits.
- [ ] **Data Integrity:** Includes "do not fabricate" and "ask rather than assume" rules.
- [ ] **Command-Specific:** Additional constraints specific to the command's domain are present.

## 5. Output Format

- [ ] **Summary Table:** Uses `Field | Value` columns with concise field names.
- [ ] **Inline Code:** Values use backticks for SHAs, numbers, branch names, and URLs.
- [ ] **Detail Table:** Optional itemized table present when the command produces per-item results (comments, findings, files).

## 6. Tone & Style

- [ ] **Third-Person Imperative:** No first/second person pronouns in Role or Context sections.
- [ ] **Concise:** Total command length under 200 lines.
- [ ] **No Filler:** Every sentence adds actionable information — no preamble or summaries restating the title.
