---
name: Code Review
description: Review changed code for correctness bugs, security issues, and missing tests. Use when asked to review, audit, or critique a diff, branch, PR, or set of changed files.
---

# Code Review

Review changed code and report actionable findings. Do not modify files during a review.

## Scope

Decide what to review before reading anything:

1. If the user named files, a branch, or a PR, review exactly that.
2. Otherwise run `git status --short` and `git diff` to find working-tree changes.
3. If there are no working-tree changes, fall back to `git diff HEAD~1..HEAD` for the last commit.
4. State the scope you picked in one line before reviewing.

Never review an entire repository unless explicitly asked. Reviewing a large diff in one pass
produces shallow findings.

## Method

Read the full content of every changed file, not just the diff hunks. A hunk hides the context
that often decides whether the change is correct.

For each changed file, work through these questions in order:

1. **Correctness** - Does the change do what its name and the surrounding code imply? Look for
   inverted conditions, off-by-one, wrong variable, missing `await`, unhandled `null`/`undefined`,
   swallowed exceptions, leaked handles or timers.
2. **Contract** - Do callers and callees still agree on signatures, return types, error behavior,
   and side-effect order? Did a public signature change without updating every caller?
3. **Security** - Unvalidated input reaching a shell, SQL, path, or URL. Secrets in source, logs,
   or error messages. A new route or handler with no authorization check. Path traversal, unsafe
   deserialization, SSRF, or open redirects.
4. **Data integrity** - A schema or migration change with no backward-compatible path. A
   non-idempotent write. A race on shared state. A missing transaction around a multi-step write.
5. **Tests** - Which behavior introduced here has no test? Was an existing test weakened,
   skipped, or deleted to make the change pass?
6. **Operability** - Logging that leaks sensitive values or runs on the hot path. Errors swallowed
   so failures look like success. No rollback path for a migration.

Read `references/review-checklist.md` for the full checklist and language-specific notes.

## Reporting

Report findings only. No praise, no walkthrough of what the code does, no restating the diff.

Order findings by severity, highest first:

- **Critical** - Data loss, a security hole, or a crash on a normal path.
- **High** - Wrong behavior on a realistic path, missing authorization, a broken contract.
- **Medium** - An edge case, an error-handling gap, or a missing test on non-trivial logic.
- **Low** - Readability, naming, dead code, small duplication.

Give each finding exactly these fields:

```
### [Critical] Short imperative title
`path/to/file.ts:42`
What breaks and the input or state that triggers it, then the concrete fix.
```

Rules for a good finding:

- Cite `file:line` for every claim. A finding without a line reference is a guess.
- Describe the trigger: the input, state, or call path that makes it fail.
- Give the fix, not just the complaint.
- Delete anything you cannot tie to a specific line and a concrete failure. A short review of
  real issues beats a long review of speculation.

## Before finishing

Re-read every finding and drop any that would not change the code. Report the survivors with a
count per severity. If nothing survives the check, say so plainly instead of inventing findings.
