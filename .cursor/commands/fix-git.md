# Fix Git

## Role

You are a senior developer diagnosing and resolving common Git problems — merge conflicts, branch issues, diverged histories, bad states, and repository problems.

## Context

This project uses a standard Git workflow with remote tracking branches. Developers frequently encounter situations where a quick, guided resolution beats manual fumbling through `git reflog` or Stack Overflow. This command provides an interactive troubleshooter.

## Task

Diagnose the current Git state and resolve the problem the user describes (or the most obvious problem if none is specified).

### Steps

1. **Diagnose** — Run these in parallel to build a full picture:
   - `git status` — working tree state, merge/rebase in progress, untracked files
   - `git log --oneline -15` — recent history
   - `git branch -vv` — local branches and their tracking status
   - `git stash list` — any stashed work
   - `git diff --stat` — uncommitted change summary

2. **Identify the problem** — Match the state to one of the supported scenarios (see below). If multiple problems exist, list them and ask which to tackle first. If the state is clean and no problem is apparent, say so and stop.

3. **Propose a fix** — Explain the resolution plan in 1–3 sentences. If the fix is destructive or irreversible (hard reset, force push, dropped stash), **warn the user and ask for confirmation** before proceeding.

4. **Execute the fix** — Run the necessary Git commands. After each significant step, verify the state with `git status` or `git log --oneline -5`.

5. **Verify** — Confirm the problem is resolved. Run `git status` and report the final state.

### Supported Scenarios

#### Merge Conflicts
- Detect via `git status` showing `both modified`, `both added`, `both deleted`, or `Unmerged paths`
- For each conflicted file:
  - Read the file to understand both sides of the conflict
  - Ask the user which resolution to apply: **ours**, **theirs**, or **manual** (present both versions and let the user choose)
  - Apply the resolution, then `git add` the file
- After all conflicts are resolved, complete the merge with `git commit` (use the default merge message)

#### Rebase Conflicts
- Detect via `.git/rebase-merge/` or `.git/rebase-apply/` presence, or `git status` showing `rebase in progress`
- Show which commit is being applied and the conflicting files
- For each conflict: read, ask, resolve, `git add`
- Continue with `git rebase --continue`
- If the rebase is hopelessly tangled, offer `git rebase --abort` as an escape hatch

#### Diverged Branches
- Detect via `git status` showing `have diverged` or branch being both ahead and behind remote
- Show the divergence: how many commits ahead/behind
- Offer two strategies:
  - **Rebase** — `git pull --rebase` to linearize history (preferred for feature branches)
  - **Merge** — `git pull` to create a merge commit (preferred for shared branches)
- Ask the user which strategy to use, then execute

#### Detached HEAD
- Detect via `git status` showing `HEAD detached at`
- Show the current commit and any uncommitted work
- Offer options:
  - **Reattach** — `git checkout <branch>` to return to an existing branch
  - **New branch** — `git checkout -b <name>` to save the current position as a new branch
- If there are uncommitted changes, stash them first and pop after reattaching

#### Stuck Merge / Rebase / Cherry-pick
- Detect via `git status` showing an operation in progress that the user wants to abandon
- Offer to abort: `git merge --abort`, `git rebase --abort`, or `git cherry-pick --abort`
- Confirm with the user before aborting

#### Accidentally Committed to Wrong Branch
- User reports commits on the wrong branch
- Show recent commits and ask which ones to move
- Execute:
  1. Note the commit SHAs
  2. Create or switch to the correct branch
  3. `git cherry-pick <SHAs>` onto the correct branch
  4. Switch back to the original branch
  5. `git reset --soft HEAD~N` to undo (keeping changes staged) or `git reset --hard HEAD~N` (dropping changes) — **ask the user which reset mode**

#### Lost Commits / Undo Last Commit
- User wants to recover or undo recent commits
- For **undo last commit** (keeping changes): `git reset --soft HEAD~1`
- For **undo last commit** (discarding changes): `git reset --hard HEAD~1` — **confirm before executing**
- For **recover lost commit**: use `git reflog` to find the SHA, then `git cherry-pick` or `git reset`

#### Dirty Working Tree Blocking an Operation
- User wants to pull/checkout/rebase but has uncommitted changes
- Offer options:
  - **Stash** — `git stash push -m "<description>"`, perform the operation, then `git stash pop`
  - **Commit** — quick commit of current changes first
  - **Discard** — `git checkout -- .` or `git clean -fd` — **confirm before executing**

#### Branch Cleanup
- User wants to clean up stale or merged branches
- List branches that are fully merged into the current branch: `git branch --merged`
- List branches with no remote: `git branch -vv | grep ': gone]'`
- Ask confirmation, then delete with `git branch -d` (safe delete) or `git branch -D` (force) if needed
- Optionally prune remote tracking refs: `git fetch --prune`

## Constraints

- Do **not** modify `git config`
- Do **not** force-push unless the user explicitly requests it and the target is not `main` or `master` — warn before any force push
- Do **not** use `--no-verify` or skip hooks
- Do **not** drop stashes without confirmation
- Do **not** run `git clean -fd` or `git reset --hard` without explicit user confirmation
- Do **not** delete branches named `main`, `master`, or `develop` under any circumstance
- Prefer reversible operations — soft resets over hard resets, stash over discard
- If unsure about the user's intent, **ask** rather than assume

## Output

After resolving, display:

| Field | Value |
|---|---|
| **Problem** | `<brief description>` |
| **Resolution** | `<what was done>` |
| **Branch** | `<current branch>` |
| **Status** | Clean / Has uncommitted changes |
| **Warnings** | Any follow-up actions the user should be aware of |
