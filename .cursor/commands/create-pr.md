# Create Pull Request

## Role

You are a senior developer creating a pull request on GitHub using the `gh` CLI, filling in the project's PR template with an accurate, thorough description derived from the branch's changes.

## Context

This project uses a PR template at `.github/PULL_REQUEST_TEMPLATE.md` with these sections:

```
## 🎟️ Issue, exception, or other link
## 📓 Change description
## 🧪 Test plan
## ✅ Before you request a review
```

PRs should have concise, imperative-mood titles matching the commit style (sentence case, no trailing period, no conventional-commit prefixes). When an issue key is provided, prepend it in brackets: `[CMDX-123] Add performance optimization`.

## Task

Create a GitHub pull request for the current branch.

### Steps

1. **Ask for options** — Prompt the user with these optional questions:
   - **Issue key / issue URL** — e.g. `CMDX-123` or a full URL. Used in the title bracket and the "Issue" section. Leave blank to skip.
   - **Base branch** — defaults to `main`. Override if targeting a different branch.
   - **Draft** — whether to create the PR as a draft. Default: no.

2. **Gather context** — Run these in parallel:
   - `git status` — verify the working tree (warn if there are uncommitted changes)
   - `git log --oneline main..HEAD` — all commits on this branch since it diverged from base
   - `git diff main...HEAD --stat` — summary of all file changes
   - `git diff main...HEAD` — full diff for content analysis
   - `git branch --show-current` — current branch name
   - `git log --oneline main..HEAD --reverse` — chronological order for narrative flow
   - Check remote tracking: `git status -sb` — determine if branch is pushed

3. **Push the branch** — If the branch has no upstream or is ahead of the remote:
   - `git push -u origin HEAD`
   - Do **not** force-push

4. **Draft the PR title** — Summarize the overall change in imperative mood:
   - If an issue key was provided, prepend it: `[CMDX-123] Add feature`
   - Keep it ≤ 72 characters
   - Should describe the "what" at a high level

5. **Draft the PR body** — Fill in each template section:

   **🎟️ Issue, exception, or other link**
   - If an issue key or URL was provided, include it here
   - If none, write "N/A"

   **📓 Change description**
   - Analyze ALL commits (not just the latest) and the full diff
   - Write a clear summary of what changed and **why**
   - Use bullet points for multiple concerns
   - Mention key files or areas affected when it adds clarity
   - Keep it factual and concise — no filler

   **🧪 Test plan**
   - List concrete steps or checks to verify the changes work
   - If specs were added/modified, mention them
   - If manual verification is needed, describe the steps
   - If no tests apply, explain why

   **✅ Before you request a review**
   - Include the checklist items from the template
   - Pre-check items that are already satisfied based on the diff

6. **Attach visuals** — If the changes involve UI, styling, or any visual behavior:
   - Run app locally (seed or generate any data required)
   - Use the `GenerateImage` tool to create a screenshot, mockup, or diagram illustrating the implemented solution
   - Upload it to the PR as a comment using `gh pr comment <number> --body "![description](image-url)"` or attach via `gh api`
   - If the changes are purely backend/config with no visual component, skip this step

7. **Create the PR** — Use `gh pr create` with a HEREDOC for the body:
   ```bash
   gh pr create --title "<title>" --base <base> [--draft] --body "$(cat <<'EOF'
   <body>
   EOF
   )"
   ```

8. **Report** — Display the result.

## Constraints

- Do **not** modify `git config`
- Do **not** force-push or run destructive Git operations
- Do **not** use `--no-verify` or skip hooks
- Do **not** push to `main` or `master` directly
- Do **not** create the PR if the branch has zero commits ahead of base — say so and stop
- If the working tree has uncommitted changes, **warn** the user and ask whether to proceed or commit first
- Use the **full PR template structure** — do not skip sections
- Derive all content from the actual diff and commits — do not fabricate changes

## Output

After creating the PR, display:

| Field | Value |
|---|---|
| **PR** | `#<number>` |
| **Title** | `<title>` |
| **URL** | `<url>` |
| **Base** | `<base branch>` |
| **Head** | `<current branch>` |
| **Draft** | Yes / No |
| **Commits** | `<count> commit(s)` |
| **Files** | `<count> file(s) changed` |
