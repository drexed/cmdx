# Git Commit

## Role

You are a senior developer committing staged and unstaged changes to the local Git repository with a clear, well-crafted commit message.

## Context

This project uses short imperative commit messages without conventional-commit prefixes. Examples from the log:

```
Add performance optimization skill
Update hooks
Setup mailer skill
Move commands to ai folder
Clean up overviews
Bump deps
```

Style rules:
- Imperative mood, sentence case, no trailing period
- First line ≤ 72 characters
- Optional body separated by a blank line for multi-concern commits
- No `feat:`, `fix:`, `chore:` prefixes
- When an issue key is provided, prepend it in brackets: `[CMDX-123] Add performance optimization skill`

## Task

Create a single Git commit for the current working-tree changes.

### Steps

1. **Ask for options** — Prompt the user with two optional questions:
   - **Issue key** — e.g. `CMDX-123`. If provided, it will be prepended to the commit message in brackets. Leave blank to skip.
   - **Push to remote** — whether to `git push` after committing. Default: no.

2. **Inspect the working tree** — Run these in parallel:
   - `git status` — identify untracked, modified, staged, and deleted files
   - `git diff` and `git diff --cached` — review both unstaged and staged changes
   - `git log --oneline -10` — sample recent messages for voice/style reference

3. **Classify changes** — Determine whether the changeset is:
   - A single logical unit → one commit
   - Multiple unrelated units → ask the user whether to commit everything together or split

4. **Draft the commit message** — Summarize the "why" in imperative mood:
   - If an issue key was provided, prepend it: `[CMDX-123] Add feature`
   - If all changes relate to one topic, use a single-line message
   - If the scope is broad, add a body with bullet points explaining each concern
   - Mention file-count or scope only when it adds clarity

5. **Stage files** — `git add -A` the relevant files:
   - Include all modified and untracked files that belong to the logical unit
   - Exclude files that likely contain secrets (`.env`, `credentials.json`, `master.key`, etc.) — warn the user if they are present

6. **Commit** — Execute the commit using a HEREDOC for the message:
   ```bash
   git commit -m "$(cat <<'EOF'
   <commit message>
   EOF
   )"
   ```

7. **Push** (conditional) — If the user opted to push, run `git push -u origin HEAD`. Do **not** force-push.

8. **Verify** — Run `git status` to confirm the commit succeeded and the working tree is in the expected state. Report the result.

## Constraints

- Do **not** push to a remote unless the user opted in
- Do **not** amend existing commits unless the user explicitly requests it
- Do **not** modify `git config`
- Do **not** use `--no-verify` or skip hooks
- Do **not** force-push or run destructive Git operations
- Do **not** commit files that contain secrets — warn and exclude them
- If the working tree is clean (nothing to commit), say so and stop

## Output

After committing, display:

| Field | Value |
|---|---|
| **Commit** | `<short SHA>` |
| **Message** | `<first line>` |
| **Files** | `<count> file(s) changed` |
| **Branch** | `<current branch>` |
| **Pushed** | Yes / No |
