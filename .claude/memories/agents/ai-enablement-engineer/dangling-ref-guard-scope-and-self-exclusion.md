---
id: dangling-ref-guard-scope-and-self-exclusion
agent: [ai-enablement-engineer]
trigger: [writing a dangling-reference or grep-based regression guard, scoping a guard to specific directories, a regression test lives in a directory the guard also scans]
rule: A dangling-ref guard must enumerate every dir that can hold live references, including scripts/, and self-exclude its own script, which necessarily contains its own search string.
evidence: [NA-79]
uses: 1
status: active
---

## Why

Two gaps surfaced in the same guard on the same story. First, `docs-pipeline-slicing.test.sh`'s
Case 5 scanned `agents_dir`/`commands_dir`/`refs_dir`/`skills_dir` but not `scripts_dir` — a real
live reference in `docs_sync_fixture_gen.py` (under `scripts/__tests__/`) slipped past review
because the guard's own directory list had a hole. Second, once `scripts_dir` was added, the guard
started flagging itself: the test script's own comments/variable assignments necessarily contain
the literal string it searches for, exactly the way `$monolith`'s own path is deliberately excluded
from the same check. Both are fixed the same way an allowlist gap is always fixed — audit the
guard's directory/exclusion list against everywhere the pattern can legitimately or illegitimately
appear, not just the directories that happened to be top of mind when the guard was first written.
