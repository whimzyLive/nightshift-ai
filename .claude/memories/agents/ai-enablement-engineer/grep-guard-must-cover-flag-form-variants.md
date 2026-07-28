---
id: grep-guard-must-cover-flag-form-variants
agent: [ai-enablement-engineer]
trigger: [grep-based CI guard for a specific CLI flag misuse, short flag alias, --flag=value form, single-quoted value]
rule: A grep guard against a hardcoded CLI flag must match its short-flag alias, `=value` form, and single-quoted values too, not just long-flag-space-value — else the defect can reappear.
evidence: [NA-78]
uses: 0
status: active
---

## Why

`--project[[:space:]]+"?[A-Z]{2,10}"?` caught `--project ET`/`--project "CER"` but missed
`--project 'ABC'` (single quotes), `--project=XYZ` (`=` form), and `-p ET` (the documented short
flag, `skills/acli/SKILL.md:76`) — all real syntaxes the same CLI accepts, verified by QA
mutation-testing. A guard that only covers the one syntax it happened to see in the original bug
report gives a false sense of coverage.

Widening to the short alias then over-corrects: a bare `-p` is a common flag on unrelated commands
(`mkdir -p DIRNAME`, `mktemp -p TMPDIR`, `gh pr create -p PROJECT`), so matching `-p` alone
false-positives on any of them with an uppercase operand.

First fix attempted: require `acli` on the same physical line as `-p`. That killed the false
positives but silently reintroduced a false NEGATIVE — this file's own real call sites (and 14
others in the scanned scope) write `acli` and its flags on separate lines joined by `\`
continuation, so `-p ET` on its own continuation line has no `acli` token on that line to match.
Verified: rewriting `refine-feature.md`'s own pinned defect site as a continuation-line `-p "ET"`
passed the guard that was supposed to catch it — the exact regression the test exists to prevent.
**A qualifier added to kill false positives must be checked against false negatives too, in the
same pass, not as a separate later step** — the two trade off against each other and only a
differential (old regex vs new regex over the same corpus) surfaces the loss.

Final fix: a denylist instead of an allowlist. Exclude `-p` lines where the flag demonstrably
belongs to a specific known other command (`mkdir|mktemp|install|mkfifo|ssh|scp|rsync|tar|gh|curl`,
tolerating intervening subcommand words for `gh pr create -p`), matched against the grep hit's
content field only (stripped of the `path:line:` prefix grep -rn prepends) so the command name
can't accidentally match inside the file path or the operand text (`mkdir -p ACLIOUT` was a real
false positive under the old same-line-`acli`-substring check, since it matched "acli" inside
"ACLIOUT"). The long-flag branch still needs no qualifier since `--project` isn't ambiguous with
other tools.
