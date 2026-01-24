Review recently modified files for coding standard violations.

1. Run `git diff --name-only` to find modified files (include untracked with `git ls-files --others --exclude-standard`). Focus on `.css`, `.js`, `.sql`, and `.html` files.

2. For each file type present, read the corresponding rule file:
   - CSS files → `.claude/rules/css.md`
   - JavaScript files → `.claude/rules/javascript.md`
   - SQL files → `.claude/rules/sql.md`
   - HTML files → `.claude/rules/html.md`

3. Read each modified file and check it against the applicable rules.

4. Report violations grouped by file, citing the rule name and the offending line(s). If no violations are found, say so.

5. After reporting, fix any violations found.
