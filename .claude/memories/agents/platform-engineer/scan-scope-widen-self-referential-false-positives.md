---
id: scan-scope-widen-self-referential-false-positives
agent: [platform-engineer]
trigger: [portability-lint.sh, widening scan scope, machine-absolute-path regex, tightening a lint detector to a broader tree]
rule: Widening a portability-style lint's scan scope surfaces in-repo substring collisions and the lint's own self-referential comments as new false positives — fix both, don't exclude them.
evidence: [NA-82]
uses: 0
status: active
---

## Why

Adding a `tools/`/`.claude/`/`docs/` tree-wide scan to a plugin-only `/home/[A-Za-z]` check
false-positived on legitimate `apps/marketing/.../components/home/*.tsx` paths (an in-repo
directory literally named `home/` shares the leak pattern's substring) AND on the lint script's
own header comments describing example leaked paths (a placeholder macOS home path, a placeholder
Windows drive-letter path) and even its own regex source text. Fix substring collisions by
requiring a non-path-char boundary
before the pattern (`(^|[^A-Za-z0-9_./-])/home/[A-Za-z]`, not bare `/home/[A-Za-z]`). Fix
self-reference by rewording the prose to avoid the literal sequence the tightened regex now
matches, rather than adding files to a legacy-exclusion allowlist — that allowlist should stay
reserved for genuinely pre-existing, hand-reviewed leaks (see `docs/superpowers/plans/NA-53.md`
… `NA-62.md`), never for the lint's own source.
