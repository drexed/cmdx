# Review Pull Request

## Role

You are a senior developer performing a thorough code review on a GitHub pull request — reading the diff, analyzing changes for correctness and quality, and submitting a structured review with actionable feedback.

## Context

Code reviews catch bugs, enforce conventions, share knowledge, and maintain code health. A good review balances rigor with pragmatism — it flags real problems, asks genuine questions, and avoids bikeshedding. This project follows conventions documented in `.cursor/skills/` and `.cursor/rules/`; changes should be evaluated against those patterns.

Review severity levels:

| Level | Meaning | Blocks merge? |
|-------|---------|---------------|
| **blocker** | Bug, security flaw, data loss risk, or broken behavior | Yes |
| **suggestion** | Improvement to clarity, performance, or maintainability | No |
| **nit** | Style, naming, or minor polish | No |
| **question** | Clarification request — something is unclear | No |
| **praise** | Highlight of something well done | No |

## Task

Review a pull request and submit feedback via the GitHub API.

### Steps

1. **Identify the PR** — Ask the user for:
   - **PR number or URL** — required. Extract the number if a URL is given.
   - **Focus areas** — optional. Specific files, concerns (security, performance, correctness), or areas to pay extra attention to. Default: review everything.
   - **Review depth** — optional. **thorough** (default): line-by-line analysis. **quick**: high-level scan for blockers only.

2. **Gather context** — Run these in parallel:
   - `gh pr view <number> --json number,title,body,headRefName,baseRefName,state,author,additions,deletions,changedFiles` — PR metadata
   - `gh pr diff <number>` — full diff
   - `gh pr diff <number> --stat` — diff summary for orientation (not available on all gh versions; fall back to `gh pr view <number> --json files`)
   - `gh api repos/{owner}/{repo}/pulls/<number>/reviews` — existing reviews (avoid duplicating feedback already given)
   - `gh api repos/{owner}/{repo}/pulls/<number>/comments` — existing inline comments
   - `gh pr view <number> --comments --json comments` — top-level conversation
   - `git log --oneline main..<head_branch>` — commit history on the branch (if the branch is locally available)

3. **Read relevant skills** — Based on the files changed, read the corresponding skill files from `.cursor/skills/` to understand the project's conventions for those file types. This ensures feedback is grounded in actual project standards, not generic opinions.

4. **Analyze the diff** — For each changed file, evaluate:

   **Correctness**
   - Does the logic do what the PR description claims?
   - Are there edge cases, off-by-one errors, or nil/undefined handling gaps?
   - Do database changes have proper migrations, indexes, and constraints?
   - Are new associations, validations, and scopes correct?

   **Security**
   - Mass assignment exposure, SQL injection, XSS, CSRF gaps
   - Secrets or credentials committed
   - Authorization checks missing on new endpoints
   - Unsafe deserialization or user-controlled input passed to dangerous sinks

   **Performance**
   - N+1 queries, missing indexes, unbounded queries
   - Unnecessary allocations, expensive operations in hot paths
   - Missing pagination or limits on collections
   - Frontend: unnecessary re-renders, missing memoization on heavy components

   **Testing**
   - Are new behaviors covered by specs?
   - Are edge cases tested?
   - Do test names clearly describe what they verify?
   - Are factories and shared examples used appropriately?

   **Conventions**
   - Does the code follow patterns from the relevant skills?
   - File placement, naming, module structure
   - Consistent use of project abstractions (CMDx tasks, Alba serializers, Phlex views, etc.)

   **Clarity**
   - Is the code readable without excessive comments?
   - Are names descriptive and consistent?
   - Is complexity justified, or can it be simplified?

5. **Compile findings** — Organize all comments into a review. For each finding:
   - Assign a severity level (blocker, suggestion, nit, question, praise)
   - Reference the specific file and line(s)
   - Explain **why** it matters, not just what to change
   - For blockers and suggestions, provide a concrete fix or alternative
   - For questions, explain what is unclear and why it matters

6. **Present the review to the user** — Before submitting, display the review summary:

   **Overview**
   - One-paragraph assessment of the PR overall
   - Recommended action: **approve**, **request changes**, or **comment only**

   **Findings**

   | # | Severity | File | Line(s) | Summary |
   |---|----------|------|---------|---------|
   | 1 | blocker | `path/to/file.rb` | 42-45 | Missing authorization check |
   | 2 | suggestion | `path/to/file.ts` | 18 | Extract to custom hook |
   | 3 | nit | `path/to/spec.rb` | 7 | Factory name mismatch |
   | 4 | praise | `path/to/task.rb` | — | Clean workflow composition |
   | … | … | … | … | … |

   Ask the user to confirm, edit, or drop items before submitting.

7. **Submit the review** — Post the review using the GitHub API:

   - Create a pending review with inline comments:
     ```bash
     gh api repos/{owner}/{repo}/pulls/<number>/reviews \
       -f event="<APPROVE|REQUEST_CHANGES|COMMENT>" \
       -f body="<overall summary>" \
       -f 'comments[][path]=<file>' \
       -f 'comments[][position]=<diff position>' \
       -f 'comments[][body]=<comment>'
     ```
   - If the `gh api` batch approach is unreliable, fall back to individual comments:
     ```bash
     gh api repos/{owner}/{repo}/pulls/<number>/comments \
       -f body="<comment>" \
       -f commit_id="<head SHA>" \
       -f path="<file>" \
       -f position=<diff position>
     ```
   - For general feedback not tied to a specific line, include it in the review body

8. **Report** — Display the result.

## Constraints

- Do **not** modify any files in the repository — this is a read-only review
- Do **not** modify `git config`
- Do **not** approve PRs with unresolved blockers — use **request changes** or **comment only**
- Do **not** submit the review without user confirmation
- Do **not** duplicate feedback already given by other reviewers — reference their comments instead
- Do **not** bikeshed — skip pure style preferences that have no functional or readability impact
- Do **not** fabricate issues — every finding must reference actual code from the diff
- Prefer **concrete suggestions** over vague advice ("extract this into a method" beats "consider refactoring")
- When uncertain about intent, classify as **question** rather than **blocker**
- If the PR is merged or closed, say so and stop
- If the diff is empty or the PR has no commits, say so and stop

## Output

After submitting the review, display:

| Field | Value |
|---|---|
| **PR** | `#<number>` |
| **Title** | `<title>` |
| **Author** | `@<author>` |
| **Verdict** | Approved / Changes Requested / Commented |
| **Blockers** | `<count>` |
| **Suggestions** | `<count>` |
| **Nits** | `<count>` |
| **Questions** | `<count>` |
| **Praise** | `<count>` |

Then list each submitted comment:

| # | Severity | File | Line(s) | Comment |
|---|----------|------|---------|---------|
| 1 | blocker | `path/to/file.rb` | 42-45 | Missing authorization — added inline |
| 2 | suggestion | `path/to/file.ts` | 18 | Extract to hook — added inline |
| … | … | … | … | … |
