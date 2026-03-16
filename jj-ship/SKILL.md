---
name: jj-ship
description: |
  Ship workflow using Jujutsu (jj): rebase onto main, run tests, review diff, bump VERSION, update CHANGELOG, commit, push, create PR. Use when asked to "jj-ship" or "ship with jj".
allowed-tools:
  - Bash
  - Read
  - edit_file
  - create_file
  - Grep
  - glob
---

# JJ-Ship: Fully Automated Ship Workflow (Jujutsu)

You are running the `/jj-ship` workflow. This is a **non-interactive, fully automated** workflow using **Jujutsu (jj)** instead of git. Do NOT ask for confirmation at any step. Run straight through and output the PR URL at the end.

**Only stop for:**
- On `main` bookmark (abort)
- Rebase conflicts that can't be auto-resolved (stop, show conflicts)
- Test failures (stop, show failures)
- Pre-landing review finds CRITICAL issues (stop, ask)
- MINOR or MAJOR version bump needed (ask — see Step 4)

**Never stop for:**
- Working copy changes (jj always tracks them — they are part of the current change)
- Version bump choice (auto-pick MICRO or PATCH — see Step 4)
- CHANGELOG content (auto-generate from diff)
- Commit message approval (auto-describe)

---

## Step 1: Pre-flight

1. Check the current bookmark. Run:
   ```bash
   jj log --no-graph -r @ -T 'bookmarks'
   ```
   If the working copy is on `main`, **abort**: "You're on main. Ship from a feature bookmark."

2. Run `jj status` to see the current state. In jj, the working copy is always a change — no "uncommitted" concept.

3. Understand what's being shipped:
   ```bash
   jj log -r 'main..@'
   ```
   This shows all changes on the current bookmark that are not on main.

4. Get a file-level summary of what changed:
   ```bash
   jj diff -r 'main..@' --stat
   ```

---

## Step 2: Rebase onto main (BEFORE tests)

Fetch from the remote and rebase the feature changes onto the latest `main`:

```bash
jj git fetch --remote origin
jj rebase -d main -b @
```

**If there are conflicts:** Run `jj status` to check. If conflicts are simple (VERSION, CHANGELOG ordering), resolve them, then `jj resolve --mark`. If conflicts are complex or ambiguous, **STOP** and show them.

**If already up to date:** Continue silently.

---

## Step 3: Run tests (on rebased code)

Run the project's test suite. Adapt these commands to whatever the project uses:

```bash
# Look for common test runners in the project
# Examples:
# npm test / npm run test
# cargo test
# go test ./...
# python -m pytest
# bin/test-lane
```

Detect the project's test infrastructure and run accordingly. Run multiple test suites in parallel if possible.

**If any test fails:** Show the failures and **STOP**. Do not proceed.

**If all pass:** Continue silently — just note the counts briefly.

---

## Step 3.5: Pre-Landing Review

Review the diff for structural issues that tests don't catch.

1. Get the full diff:
   ```bash
   jj diff -r 'main..@'
   ```

2. Review for common issues:
   - SQL injection / unsafe queries
   - Hardcoded secrets or API keys
   - Missing error handling at system boundaries
   - Breaking API changes without migration path

3. Output a summary: `Pre-Landing Review: N issues (X critical, Y informational)`

4. **If CRITICAL issues found:** Stop and ask for each one with options:
   - A) Fix it now
   - B) Acknowledge and ship anyway
   - C) It's a false positive — skip

5. **If no issues found:** Output `Pre-Landing Review: No issues found.` and continue.

---

## Step 4: Version bump (auto-decide)

1. Read the current `VERSION` file.

2. **Auto-decide the bump level based on the diff:**
   ```bash
   jj diff -r 'main..@' --stat | tail -1
   ```
   - **MICRO/PATCH** (smallest digit): < 50 lines changed, trivial tweaks, typos, config
   - **PATCH** (next digit): 50+ lines changed, bug fixes, small-medium features
   - **MINOR**: **ASK the user** — only for major features or significant architectural changes
   - **MAJOR**: **ASK the user** — only for milestones or breaking changes

3. Compute the new version. Bumping a digit resets all digits to its right to 0.

4. Write the new version to the `VERSION` file.

---

## Step 5: CHANGELOG (auto-generate)

1. Read `CHANGELOG.md` header to understand the format.

2. Auto-generate the entry from all changes on the bookmark:
   ```bash
   jj log -r 'main..@' --no-graph -T 'description ++ "\n"'
   ```
   And the full diff:
   ```bash
   jj diff -r 'main..@'
   ```

3. Categorize into sections:
   - `### Added` — new features
   - `### Changed` — changes to existing functionality
   - `### Fixed` — bug fixes
   - `### Removed` — removed features

4. Insert after the file header, dated today. Format: `## [X.Y.Z.W] - YYYY-MM-DD`

**Do NOT ask the user to describe changes.** Infer from the diff and change descriptions.

---

## Step 6: Commit (squash or split into logical changes)

**Goal:** Create clean, logical changes that are easy to review and bisect.

In Jujutsu, the working copy is always a change. To finalize:

1. **If the change set is small** (< 50 lines across < 4 files), describe the current change and squash:
   ```bash
   jj describe -m "<type>: <summary>"
   ```

2. **If the change set is large**, split into logical changes using `jj split`:
   ```bash
   jj split --interactive
   ```
   Then describe each change:
   ```bash
   jj describe -r <change-id> -m "<type>: <summary>"
   ```

3. **Commit ordering** (earlier changes first):
   - Infrastructure: migrations, config, routes
   - Models & services (with their tests)
   - Controllers & views (with their tests)
   - VERSION + CHANGELOG: always the final change

4. The **final change** gets the version tag and co-author trailer:
   ```bash
   jj describe -m "$(cat <<'EOF'
   chore: bump version and changelog (vX.Y.Z.W)

   Co-Authored-By: Amp <noreply@ampcode.com>
   EOF
   )"
   ```

---

## Step 7: Push

Push the bookmark to the remote:

```bash
jj git push --bookmark <bookmark-name>
```

If the bookmark doesn't exist on the remote yet, jj will create it.

**Never force push** unless explicitly asked.

---

## Step 8: Create PR

Create a pull request using `gh` (GitHub CLI):

```bash
gh pr create --title "<type>: <summary>" --body "$(cat <<'EOF'
## Summary
<bullet points from CHANGELOG>

## Pre-Landing Review
<findings from Step 3.5, or "No issues found.">

## Test plan
- [x] All tests pass

🤖 Generated with [Amp](https://ampcode.com)
EOF
)"
```

**Output the PR URL** — this should be the final output the user sees.

---

## Important Rules

- **Never skip tests.** If tests fail, stop.
- **Never skip the pre-landing review.**
- **Never force push** unless explicitly asked.
- **Never ask for confirmation** except for MINOR/MAJOR version bumps and CRITICAL review findings.
- **Date format in CHANGELOG:** `YYYY-MM-DD`
- **The goal is: user says `/jj-ship`, next thing they see is the review + PR URL.**

## Jujutsu Quick Reference

| Git concept | Jujutsu equivalent |
|---|---|
| `git branch` | `jj bookmark` |
| `git commit` | `jj commit` / `jj describe` + `jj new` |
| `git merge` | `jj rebase` (preferred) or `jj merge` |
| `git fetch` | `jj git fetch` |
| `git push` | `jj git push` |
| `git diff main..HEAD` | `jj diff -r 'main..@'` |
| `git log main..HEAD` | `jj log -r 'main..@'` |
| `git status` | `jj status` |
| staged/unstaged | N/A — working copy is always a change |
| `git stash` | `jj new` (current change is preserved) |
