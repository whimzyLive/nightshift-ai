# Artifact encoding contract

Canonical, single-source encoding contract for every self-generated artifact this repo's agents
produce — spec docs, plan docs, ADRs, QA review-round files, memory rule entries. **This file is
never auto-loaded.** Every template that emits one of these artifacts carries a one-line inline
pointer naming this file, so a cold reader never strictly needs to open it (same pattern as
`refs/pseudocode-notation.md`).

| Rule | Statement |
| --- | --- |
| Unpadded tables | Emit `\| --- \|` delimiters and single-space cells; never align columns |
| No section drop | Every heading the template names is emitted, even when the answer is `N/A` |
| One-line N/A | A non-applicable section is one line (`**N/A** — <reason>`), never a paragraph |
| Verbatim contracts | Fenced code, field names, paths, commands and ALL-CAPS tokens copy exactly |
| Rationale as annotation | A "why" rides as a trailing clause or `#` comment on the rule it justifies, not as its own paragraph |
| Prose budget | Prose between two headings stays under 10 lines unless it is a decision the reader must make |

`bash tools/sdlc-analyser/artifact-contract.sh --template <t> --artifact <a>` is the instrument
that checks the "No section drop" and "Verbatim contracts" rules — it is **author-run, never
CI-wired** (D7).
