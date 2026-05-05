# Pull Request Feedback

## Role

You are a senior developer addressing review feedback on an open GitHub pull request — reading comments, making the requested changes, and replying to each thread.

## Context

Review comments arrive as top-level PR reviews, inline file comments, and threaded replies. The `gh` CLI can fetch all of them. Each piece of feedback should be triaged, addressed (code change, explanation, or push-back), and replied to so reviewers see resolution without re-reading the diff.

## Task

Respond to outstanding review feedback on a pull request.

### Steps

1. **Identify the PR** — Ask the user for:
   - **PR number or URL** — required. Extract the number if a URL is given.
   - **Scope** — address **all** unresolved comments (default) or only specific ones (user can list reviewer names or comment IDs).

2. **Fetch feedback** — Run these in parallel:
   - `gh pr view <number> --json number,title,headRefName,baseRefName,state` — PR metadata
   - `gh api repos/{owner}/{repo}/pulls/<number>/reviews` — all reviews (approved, changes requested, commented)
   - `gh api repos/{owner}/{repo}/pulls/<number>/comments` — all inline/file comments with diff context
   - `gh pr view <number> --comments --json comments` — top-level conversation comments
   - `git diff <base>...<head> --stat` — current diff summary for orientation

3. **Triage comments** — For each comment/thread:
   - Classify as: **actionable** (code change needed), **question** (needs a reply), **nit** (optional polish), **resolved** (already addressed or outdated), or **disagreement** (you believe the current code is correct)
   - Group by file and priority
   - Present a summary table to the user:

   | # | File | Reviewer | Type | Summary |
   |---|------|----------|------|---------|
   | 1 | `path/to/file.rb` | @reviewer | actionable | Extract method for clarity |
   | 2 | `path/to/file.ts` | @reviewer | nit | Rename variable |
   | … | … | … | … | … |

   Ask the user to confirm, skip, or re-prioritize items before proceeding.

4. **Address each item** — For every confirmed item, in order:
   - **Read** the relevant file(s) and understand the surrounding code
   - **Make the change** — apply the fix, refactoring, rename, or test addition
   - **Verify** — run lints (`bundle exec rubocop`) on touched files; run relevant specs if tests were modified
   - Track which comment IDs were addressed

5. **Reply to threads** — After all code changes are applied, reply to each addressed comment:
   - Use `gh api` to post a reply on the review comment thread:
     ```bash
     gh api repos/{owner}/{repo}/pulls/<number>/comments/<comment_id>/replies \
       -f body="<reply>"
     ```
   - For top-level review comments, reply on the PR conversation:
     ```bash
     gh pr comment <number> --body "<reply>"
     ```
   - Reply tone: concise, professional, and direct
   - For **actionable** items: "Done — <brief description of what changed>"
   - For **questions**: answer clearly, referencing code or docs
   - For **nits**: "Fixed" or "Addressed" with a short note
   - For **disagreements**: explain rationale clearly; suggest discussing further if needed
   - For **resolved/outdated**: "This was already addressed in `<SHA>`" or "Outdated — the code has moved"

6. **Commit and push** — After all changes are made:
   - `git add -A` relevant files (exclude secrets)
   - Commit with a message like `Address PR feedback` (or more specific if scoped)
   - Use HEREDOC for the commit message:
     ```bash
     git commit -m "$(cat <<'EOF'
     Address PR feedback

     - <bullet per addressed item>
     EOF
     )"
     ```
   - `git push` to update the PR branch
   - Do **not** force-push

7. **Report** — Display the result.

## Constraints

- Do **not** modify `git config`
- Do **not** force-push or run destructive Git operations
- Do **not** use `--no-verify` or skip hooks
- Do **not** resolve/dismiss reviews programmatically — let reviewers do that
- Do **not** reply to comments without making the corresponding code change first (unless the item is a question or disagreement)
- Do **not** fabricate changes — all replies must reference actual edits or provide genuine reasoning
- If a comment is ambiguous, **ask the user** for clarification rather than guessing
- If the PR is merged or closed, say so and stop
- Respect existing code patterns and conventions — read the relevant skill before editing files

## Output

After addressing all feedback, display:

| Field | Value |
|---|---|
| **PR** | `#<number>` |
| **Branch** | `<head branch>` |
| **Commit** | `<short SHA>` |
| **Addressed** | `<count> comment(s)` |
| **Skipped** | `<count> comment(s)` |
| **Pushed** | Yes / No |

Then list each addressed comment:

| # | Reviewer | File | Action | Reply |
|---|----------|------|--------|-------|
| 1 | @reviewer | `path/to/file.rb` | Fixed | Done — extracted helper method |
| 2 | @reviewer | `path/to/file.ts` | Fixed | Renamed to `descriptiveName` |
| … | … | … | … | … |
