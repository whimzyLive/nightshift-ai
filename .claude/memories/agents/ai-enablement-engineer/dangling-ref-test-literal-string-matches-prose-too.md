---
id: dangling-ref-test-literal-string-matches-prose-too
agent: [ai-enablement-engineer]
trigger: [dangling-reference regression test, grep -rlF for an old filename, renaming or splitting a file whose old name is referenced descriptively in prose]
rule: A dangling-reference test that greps file contents for a literal old filename string also flags legitimate historical/descriptive prose mentions of that filename in new files — never write the literal old filename string anywhere except the file that intentionally keeps that path (e.g. a thin index); describe it generically instead ("the former monolithic reference file").
evidence: [NA-79]
uses: 0
status: active
---

## Why

The NA-79 regression test's dangling-reference case ran
`grep -rlF "docs-pipeline.md" "$agents_dir" "$commands_dir" "$refs_dir" "$skills_dir" | grep -vF "$monolith"`
— a blunt content-level literal-string match, excluded only for the monolith's own path. Writing
`docs-pipeline-core.md`'s new header prose ("split from the former `docs-pipeline.md` monolith")
and `doc-types.md`'s generic index pointer both reintroduced the literal substring `docs-pipeline.md`
in files the exclusion did not cover, failing the test even though both were intentional,
correct historical/pointer prose, not real dangling references. Fixed by rephrasing both to avoid
the literal old filename entirely. When a test's dangling-reference check is filename-string-based
rather than semantic, treat the exact old string as unusable in prose anywhere outside the
file that's meant to keep it.
