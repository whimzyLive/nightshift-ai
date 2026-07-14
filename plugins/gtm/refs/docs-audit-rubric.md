# Docs Audit Rubric

Applies at `docs-auditor` agent step 2 (Audit each file against the rubric), dispatched by
`/gtm:docs`. Every `DocsAuditFinding.rubricRef` value **must** be one of the rubric IDs below —
this file is the traceable source those references point at (NA-7 AC-1: "audits existing
documentation against ai-seo and content-strategy guidance").

Each rubric ID maps to exactly one `DocsFindingCategory` (the six values the command/agent
contract defines: `metadata`, `structure`, `keyword-intent`, `answerability`,
`internal-linking`, `freshness`) and cites the marketingskills criterion it operationalizes —
`ai-seo` or `content-strategy`. "Severity guidance" is a default; the agent may adjust per-finding
severity when the concrete instance is clearly worse or milder than the default (e.g. a stuffed
keyword in one paragraph vs. across an entire page).

## metadata

Title, heading-as-description, and structured-data signals a doc carries about itself.

| ID       | Check                                                                                                                                        | Source                                                                                                                                       | Severity default |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| `META-1` | The page has exactly one H1/title, and it matches the page's primary query/topic (not a generic label)                                       | ai-seo — Structural rules ("headings that match how people phrase queries"); content-strategy — "Use clear titles that match search queries" | medium           |
| `META-2` | The opening paragraph is a self-contained 40–60 word definition/answer block that would work extracted on its own                            | ai-seo — Pillar 1 Structure, "Definition blocks" + "Keep key answer passages to 40-60 words"                                                 | medium           |
| `META-3` | MDX/Markdown frontmatter `description` (or equivalent front-matter summary field) is present and non-generic, not just copied from the title | content-strategy — "Place keywords in title, headings, first paragraph"                                                                      | low              |
| `META-4` | A page shaped like an FAQ, HowTo, or comparison carries a note that it's a schema-markup candidate (flag-only — no schema is authored)       | ai-seo — "Schema Markup for AI" table                                                                                                        | low              |

`META-4` is a **flag-only** check — recommending schema markup, not implementing it (implementing
`docs.json`/structured data is out of scope for `/gtm:docs`, see the spec's Out of Scope section).

## structure

Heading hierarchy, scannability, and paragraph/list/table shape.

| ID         | Check                                                                                         | Source                                                        | Severity default |
| ---------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ---------------- |
| `STRUCT-1` | Heading hierarchy is well-formed — exactly one H1, no skipped levels (H2 → H4 with no H3)     | ai-seo — Pillar 1 Structure, "Structural rules"               | medium           |
| `STRUCT-2` | A multi-step procedure is rendered as a numbered list, not a prose paragraph                  | ai-seo — "Numbered lists beat paragraphs for process content" | medium           |
| `STRUCT-3` | Comparison content (X vs Y, feature matrices, option lists) is rendered as a table, not prose | ai-seo — "Tables beat prose for comparison content"           | medium           |
| `STRUCT-4` | No paragraph spans multiple unrelated ideas — each paragraph reads as one clear idea          | ai-seo — "Each paragraph should convey one clear idea"        | low              |

## keyword-intent

Target-query/intent coverage and terminology consistency.

| ID     | Check                                                                                                                                                                     | Source                                                                                                             | Severity default |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ---------------- |
| `KW-1` | The page maps to an identifiable buyer-journey stage (awareness / consideration / decision / implementation) and its wording matches that stage's expected query language | content-strategy — "Keyword Research by Buyer Stage"                                                               | medium           |
| `KW-2` | Product/feature terminology is consistent with `.agents/product-marketing.md` positioning language — no competing names for the same concept across the corpus            | content-strategy — positioning consistency; ai-seo — "Technical terms +18%, unique vocabulary +15%" citation boost | medium           |
| `KW-3` | The page covers the query-fan-out cluster for its topic (the related sub-questions a reader or AI system would expect), not just the one named topic in isolation         | ai-seo — "Query Fan-Out (Google AI Search)"                                                                        | low              |
| `KW-4` | No unnatural, repeated keyword-stuffing density                                                                                                                           | ai-seo — "keyword stuffing actively hurts AI visibility (-10%)"                                                    | high             |

## answerability

AI-search / `llms.txt` / question-shaped-content discoverability (the `ai-seo`-specific pillar).

| ID      | Check                                                                                                             | Source                                                                        | Severity default |
| ------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------- |
| `ANS-1` | An FAQ-shaped block (or equivalent Q&A section) exists for the genuinely common questions the page's topic raises | ai-seo — "FAQ blocks" content pattern, `FAQPage` schema note                  | low              |
| `ANS-2` | Claims and statistics carry a cited, dated source                                                                 | ai-seo — Pillar 2 Authority, "Cite sources +40%, Add statistics +37%"         | medium           |
| `ANS-3` | Content is not gated behind auth or rendered only via client-side JS that would block AI/agent extraction         | ai-seo — "Gating all content... AI can't access gated content" common mistake | high             |
| `ANS-4` | Where relevant, an `llms.txt` (or repo-root equivalent) references this doc/page for AI-crawler discoverability   | ai-seo — "`/llms.txt` — Context file for AI systems"                          | low              |

## internal-linking

Cross-links and orphan-page detection.

| ID       | Check                                                                                                      | Source                                                                                | Severity default |
| -------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ---------------- |
| `LINK-1` | The page links back to its parent hub/index page — no orphan pages with zero inbound links from the corpus | content-strategy — "Hub and Spoke... Interlink strategically"                         | medium           |
| `LINK-2` | Related docs cross-link each other (e.g. a concept doc links the how-to doc for the same feature)          | content-strategy — "Hub and Spoke" topic clusters                                     | low              |
| `LINK-3` | Every relative internal link resolves to a file that actually exists in the corpus (no dead links)         | general indexability hygiene; ai-seo — extractability depends on a working page graph | high             |

## freshness

Content currency vs. product reality.

| ID        | Check                                                                                                                                                         | Source                                                                | Severity default |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------- |
| `FRESH-1` | Doc content matches current product reality — no references to removed/renamed features, deprecated commands, or superseded flows                             | ai-seo — "Freshness signals... Remove or update outdated information" | high             |
| `FRESH-2` | A "last updated" / date signal is present and reasonably recent for doc types that warrant one (changelog-adjacent content, not evergreen reference material) | ai-seo — "'Last updated' displayed prominently... within 6 months"    | low              |
| `FRESH-3` | Version-specific instructions (CLI flags, config keys, examples) match the current codebase, not a prior major version                                        | ai-seo — E-E-A-T, "specific, detailed information"                    | medium           |

## Finding-group taxonomy

`docs-auditor` step 3 groups findings into PR-sized units, biased toward the fewest PRs possible
(the spec's Resolved Decision). Group **slugs** — used to build the `gtm/docs-audit/<group-slug>`
branch name — follow one of two shapes:

- **Merged (default when scope allows):** all findings from this run go into a single PR with
  slug `all` → branch `gtm/docs-audit/all`.
- **Per-category (only for a genuinely large documentation scope):** one slug per
  `DocsFindingCategory` value present in the findings — `metadata`, `structure`,
  `keyword-intent`, `answerability`, `internal-linking`, `freshness` → branch
  `gtm/docs-audit/<category>`, e.g. `gtm/docs-audit/metadata`.

Never invent a third grouping shape (e.g. per-file) — the spec's Resolved Decisions explicitly
supersedes an earlier per-file suggestion in favor of per-category, fewest-PRs-possible.
