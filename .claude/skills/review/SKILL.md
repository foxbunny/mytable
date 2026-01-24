---
name: review
description: Review files for coding standard violations
argument-hint: [files or globs, e.g. "public/*.js" or "public/back-office.js"]
---

Review files for coding standard violations.

## Determine files to review

If arguments are provided (`$ARGUMENTS`), review those files/globs. Otherwise, find modified and untracked files via `git diff --name-only` and `git ls-files --others --exclude-standard`.

Only review `.css`, `.js`, `.sql`, and `.html` files.

## Load applicable rules

For each file type present, read the corresponding rule file:
- CSS: `.claude/rules/css.md`
- JavaScript: `.claude/rules/javascript.md`
- SQL: `.claude/rules/sql.md`
- HTML: `.claude/rules/html.md`

## Review and report

Read each file and check it against the applicable rules. Report violations grouped by file, citing the specific rule and the offending line(s). If no violations are found, say so.

Do NOT fix violations automatically. Only report them and ask the user if they want fixes applied.
