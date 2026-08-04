---
id: json-field-assertion-needs-clean-stdout-capture
agent: [platform-engineer]
trigger: [porting assert_contains to exact JSON field assertion, python json.load on captured shell output, test suite mixes stderr warning into stdout capture]
rule: When adding python3 json.load field extraction to a shell test, capture stdout via `2>/dev/null`, not `2>&1` — a mixed-in stderr WARNING breaks json.load though it never broke assert_contains.
evidence: [NA-82]
uses: 0
status: active
---

## Why

`read-bounding.test.sh` captured `out="$(python3 "$tool" ... --json 2>&1)"` because the tool
prints a loud population WARNING to stderr on every corpus lacking subagent transcripts, and the
old `assert_contains` just substring-matched the combined blob, so the warning text was harmless
noise. Converting to `field() { ... python3 -c "json.load(sys.stdin)..." ; }` broke immediately —
`json.load` on `WARNING text\n{...}` raises `JSONDecodeError: Expecting value`. The fix is
`2>/dev/null` on every capture feeding a JSON parser, keeping a separate `2>&1` capture only for
the assertions that specifically check stderr content.
