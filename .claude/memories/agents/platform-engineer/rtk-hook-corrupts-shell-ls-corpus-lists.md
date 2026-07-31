---
id: rtk-hook-corrupts-shell-ls-corpus-lists
agent: [platform-engineer]
trigger: [building a corpus-list.txt, pinning a transcript file list, shell ls glob under rtk hook, corpus list path corrupted]
rule: When generating a corpus/path-list file via shell `ls`, use Python `glob.glob` instead — the local rtk hook can rewrite `ls` to append trailing size text, corrupting paths.
evidence: [NA-90, NA-91]
uses: 2
status: active
---

## Why

Building NA-90's `corpus-list.txt` with `ls "$proj"/*/subagents/*.jsonl` silently produced lines
like `.../agent-a696e72b7bc797c99.jsonl  1.1M` — the user's local rtk hook rewrote the bare `ls`
into a size-annotated listing. `os.path.isfile()` on the corrupted line failed silently (no error,
just excluded from `resolved_paths`), so the resulting report showed `subagentTranscripts: 0` with
no loud failure — exactly the confident-wrong-conclusion shape the ASSERT/WARNING in
`read-bounding.py`'s corpus rule exists to catch, except the corruption happened one layer
upstream of the tool, in the shell step that built its input. Building the same list with Python's
`glob.glob` sidesteps the hook entirely and is the fix. Always spot-check a handful of lines in a
generated corpus/path-list for trailing garbage before trusting a `0` or a suspiciously round
partition count.
