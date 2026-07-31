---
id: reuse-readonly-analyser-module-for-uncovered-metric
agent: [ai-enablement-engineer]
trigger: [measurement block needs a stat a read-only tools/ analyser doesn't emit, tool is owned by another agent so it is out of scope to edit, filling in a PR measurement-block.txt]
rule: When a needed metric isn't in a read-only analyser's JSON and editing tools/ is out of scope, importlib-load its module and call its functions — never hand-parse or re-derive the logic.
evidence: [NA-90]
uses: 0
status: active
---

## Why

Task 2.6 needed `wholeReadsOverThreshold`'s aggregate est-tokens and its % of read volume, but
`read-bounding.py`'s JSON report only carries the count. `tools/sdlc-analyser/**` is
platform-engineer's (Phase 1 already merged, out of scope to modify here), and hand-writing a
parallel JSONL scanner risks silently drifting from the sizing/windowed/threshold rules the tool
already encodes correctly. `importlib.util.spec_from_file_location` + `exec_module` loads the
script as a module without needing it on `sys.path` or installed as a package, so a scratch script
can call `read_corpus_list`, `resolve_paths`, `scan`, `size_reads` directly and stay byte-identical
to the tool's own classification.
