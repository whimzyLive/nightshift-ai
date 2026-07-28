---
id: markdown-corruption-classes-beyond-quad-fence
agent: [ai-enablement-engineer]
trigger: [prettier sweep corrupts markdown, pipe in table cell, wrapped ordinal parsed as list item, bold wrapping code spans, nested backtick code span in prose]
rule: A benign-looking `prettier --write` sweep can corrupt markdown in shapes that never touch a quad fence at all.
evidence: [NA-62, NA-58, NA-61, NA-7, NA-78]
uses: 0
status: active
---

## Why

Distinct corruption shapes found across stories, all from the same root cause (trusting one
regression signature as sufficient): (1) an unescaped literal `||` inside a code span sitting in a
markdown table cell gets split into phantom-column padding by Prettier's table formatter unless
backslash-escaped (`\|`) — grep any file with a table for literal `|`/`||` inside a code span before
sweeping. (2) A hand-wrapped sentence with "...(Condition\n1) and exported..." — CommonMark permits
ordinal `1` (not 2+) to interrupt a paragraph with no blank line, so remark reads a wrapped "1)" as a
new list item; grep for `^[0-9]+[.)][[:space:]]` pre-sweep and eyeball whether each hit is genuine or
a wrapped continuation (lowercase word/conjunction right after the marker is the tell). (3) A code
span with a leading/trailing space (`` ` — ` ``) is canonicalized to the trimmed form (`` `—` ``) on
`--write`, silently dropping intentional whitespace meaning — say "a space, an em-dash, and a space"
in prose instead of relying on a code span's internal whitespace. (4) Wrapping `**bold**` around
multiple adjacent inline code spans joined by a plain word (``**`a` and `b` only**``) collapses the
surrounding spaces on the first write — bold only a single word/phrase outside the code spans
instead. (5) A fence nested inside another fence of the same backtick-length (e.g. an inner
example fence inside an outer SKILL.md template fence) is CommonMark-ambiguous — the inner fence can
close the outer one early; widen the OUTER fence one backtick beyond the longest fence run used
anywhere inside it, don't wait for Prettier to "fix" it. (6) Writing one code span's closing
backtick(s) directly adjacent to a second span's opening backtick(s), with no space or word between
them, is CommonMark-ambiguous about where the first span ends and the second begins — Prettier's
formatter can misparse the boundary and collapse whitespace across a much wider run of the paragraph
than the two adjacent spans themselves (observed: several unrelated sentences afterward lost their
inter-word spacing around later, otherwise-unrelated code spans). Always keep at least a space or a
plain word between two adjacent inline code spans, and never wrap one code span's backticks around
text that itself contains another backtick-delimited term. In every case: verify with the real
two-pass copy → `--write` → `diff` protocol (see `prettier-idempotency-verification-protocol`), not
a single `--check`, since first-write corruption is common and a same-file/same-command sanity check
right after an edit can look clean while the corruption has moved onto an untouched neighboring line
in the same reflow unit (a whole paragraph containing this anti-pattern is unstable, not just the
specific flagged line).
