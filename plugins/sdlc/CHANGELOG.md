## 0.45.9 (2026-08-08)

### 🚀 Features

- **sdlc:** validate the 7-field rule schema at capture write time (NA-103) ([74a3bdc](https://github.com/whimzyLive/nightshift-ai/commit/74a3bdc))
- **sdlc:** add one-shot memory-corpus migration script (NA-102) ([f341e5f](https://github.com/whimzyLive/nightshift-ai/commit/f341e5f))
- **sdlc:** NA-101 make promote-target root-relative and normalise it once on promotion ([e90d341](https://github.com/whimzyLive/nightshift-ai/commit/e90d341))
- **sdlc:** NA-101 write captures into the resolved memory root ([b59b47e](https://github.com/whimzyLive/nightshift-ai/commit/b59b47e))
- **sdlc:** NA-101 validate memory frontmatter across both roots ([d5d283e](https://github.com/whimzyLive/nightshift-ai/commit/d5d283e))
- **sdlc:** NA-101 collect rules from the resolved root and the legacy root ([ba62160](https://github.com/whimzyLive/nightshift-ai/commit/ba62160))
- **sdlc:** NA-101 list captures from the resolved root and the legacy root ([9d6420d](https://github.com/whimzyLive/nightshift-ai/commit/9d6420d))
- **sdlc:** NA-101 add memory-root --ensure layout creation ([4456062](https://github.com/whimzyLive/nightshift-ai/commit/4456062))
- **sdlc:** NA-101 add the memory-root resolver library ([02426b5](https://github.com/whimzyLive/nightshift-ai/commit/02426b5))

### 🩹 Fixes

- **sdlc:** finish the counter-only sweep, validate uses on the full-rule path, replace the phrasing-based ref sweep ([#237](https://github.com/whimzyLive/nightshift-ai/issues/237))
- **sdlc:** sweep refs/ for the inverted counter-only contract, drop the SHA-pinned test fixture ([43a02ee](https://github.com/whimzyLive/nightshift-ai/commit/43a02ee))
- **sdlc:** close the QA gate findings on NA-103's capture/frontmatter validation ([fb5f4d7](https://github.com/whimzyLive/nightshift-ai/commit/fb5f4d7))
- **sdlc:** fix the delete-failure fallback order and scope, drop a reintroduced BRE (PR #235 round 2) ([#235](https://github.com/whimzyLive/nightshift-ai/issues/235))
- **sdlc:** make the copy list-driven, close portability and messaging gaps (PR #235 round 1) ([#235](https://github.com/whimzyLive/nightshift-ai/issues/235))
- **sdlc:** treat an unreadable destination as occupied, make delete-failure recovery actionable (NA-102) ([3eaa173](https://github.com/whimzyLive/nightshift-ai/commit/3eaa173))
- **sdlc:** stop trusting find's emptiness as an affirmative safety signal (NA-102) ([b1a54cd](https://github.com/whimzyLive/nightshift-ai/commit/b1a54cd))
- **sdlc:** close vacuous-pass and destructive-path gaps in memory migration (NA-102) ([5e992e2](https://github.com/whimzyLive/nightshift-ai/commit/5e992e2))
- **sdlc:** NA-101 refuse to run gen-goldens.py against a dirty plans tree ([583a2a8](https://github.com/whimzyLive/nightshift-ai/commit/583a2a8))
- **sdlc:** NA-101 regenerate corpus-expectation.tsv from a clean tree and widen the provenance check ([f889e54](https://github.com/whimzyLive/nightshift-ai/commit/f889e54))
- **sdlc:** NA-101 explain the init.md Step 4h rewrite's provenance ([44770c1](https://github.com/whimzyLive/nightshift-ai/commit/44770c1))
- **sdlc:** NA-101 exclude the legacy in-repo capture root from the workspace-integrity guard ([8b4530f](https://github.com/whimzyLive/nightshift-ai/commit/8b4530f))
- **sdlc:** NA-101 correct the plan doc's corpus-expectation.tsv scope claim and regenerate it ([fa71aee](https://github.com/whimzyLive/nightshift-ai/commit/fa71aee))
- **sdlc:** NA-101 point qa-engineer-playbook and qa-gate-runner at memory-root.sh ([760a054](https://github.com/whimzyLive/nightshift-ai/commit/760a054))
- **sdlc:** NA-101 close the memory-root ensure dangling-symlink gap Copilot found ([cf2022e](https://github.com/whimzyLive/nightshift-ai/commit/cf2022e))
- **sdlc:** NA-101 resolve check-frontmatter's legacy captured/** scan via primary worktree ([bcd6309](https://github.com/whimzyLive/nightshift-ai/commit/bcd6309))
- **sdlc:** NA-101 make the ensure probe catch dangling symlinks and a directory-shaped .gitignore ([deca920](https://github.com/whimzyLive/nightshift-ai/commit/deca920))
- **sdlc:** NA-101 stop success-path stderr from contaminating the resolved memory root ([bcb1439](https://github.com/whimzyLive/nightshift-ai/commit/bcb1439))
- **sdlc:** NA-101 point domain-agent-handoff and analyze-protocol at memory-root.sh ([2e310fa](https://github.com/whimzyLive/nightshift-ai/commit/2e310fa))
- **sdlc:** NA-101 make memory-root --ensure probe-first and cover remaining error paths ([b5e16c0](https://github.com/whimzyLive/nightshift-ai/commit/b5e16c0))
- **sdlc:** NA-101 surface the real resolver failure reason instead of discarding stderr ([b09d6f7](https://github.com/whimzyLive/nightshift-ai/commit/b09d6f7))
- **sdlc:** NA-101 regenerate plan-slice corpus-expectation.tsv for NA-101.md ([41b174c](https://github.com/whimzyLive/nightshift-ai/commit/41b174c))
- **sdlc:** NA-101 resolve the capture-exclusion root via memory-root.sh ([7f1a1c5](https://github.com/whimzyLive/nightshift-ai/commit/7f1a1c5))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.8 (2026-08-06)

### 🚀 Features

- **sdlc:** promote captured learnings through the distill gate ([012f115](https://github.com/whimzyLive/nightshift-ai/commit/012f115))
- **sdlc:** add capture promotion to the memory maintenance op ([b0f854e](https://github.com/whimzyLive/nightshift-ai/commit/b0f854e))
- **sdlc:** sanction capture promotion under memory-ownership exception 2 ([f85ca46](https://github.com/whimzyLive/nightshift-ai/commit/f85ca46))
- **sdlc:** capture QA review rounds instead of committing them ([a272d5d](https://github.com/whimzyLive/nightshift-ai/commit/a272d5d))
- **sdlc:** retarget domain-agent memory writes to learning captures ([78ccbf7](https://github.com/whimzyLive/nightshift-ai/commit/78ccbf7))
- **sdlc:** validate captured learnings as warnings only ([61e4d87](https://github.com/whimzyLive/nightshift-ai/commit/61e4d87))
- **sdlc:** enumerate the learning-capture corpus ([c2aa1ea](https://github.com/whimzyLive/nightshift-ai/commit/c2aa1ea))
- **sdlc:** write rule and review learning captures to the staging area ([d6e6e83](https://github.com/whimzyLive/nightshift-ai/commit/d6e6e83))
- **sdlc:** resolve capture staging root to the primary checkout ([60cd6f9](https://github.com/whimzyLive/nightshift-ai/commit/60cd6f9))
- **sdlc:** add shared frontmatter helper for capture scripts ([2ea1344](https://github.com/whimzyLive/nightshift-ai/commit/2ea1344))

### 🩹 Fixes

- **sdlc:** three Copilot findings — capture-only warn, slash-less target, silent-empty corpus ([c922df3](https://github.com/whimzyLive/nightshift-ai/commit/c922df3))
- **sdlc:** STOP/BLOCKED on a cannot-verify workspace assert, not just VIOLATED ([6e199e5](https://github.com/whimzyLive/nightshift-ai/commit/6e199e5))
- **sdlc:** a cannot-verify workspace state is a hard error, never a fabricated VIOLATED ([409af60](https://github.com/whimzyLive/nightshift-ai/commit/409af60))
- **sdlc:** close the shared counter-only smuggle path, drop test rationale comments ([b5fe436](https://github.com/whimzyLive/nightshift-ai/commit/b5fe436))
- **sdlc:** correct sibling-ref drift and off-by-one pointers in the capture docs ([a28700f](https://github.com/whimzyLive/nightshift-ai/commit/a28700f))
- **sdlc:** exempt the shared/ counter-only path, bound round, drop a why-comment ([e2f1a19](https://github.com/whimzyLive/nightshift-ai/commit/e2f1a19))
- **sdlc:** document the payload-file frontmatter channel in the memory-write contract ([af72c95](https://github.com/whimzyLive/nightshift-ai/commit/af72c95))
- **sdlc:** resolve the distill halt-row contradiction for a non-empty capture corpus ([0344f65](https://github.com/whimzyLive/nightshift-ai/commit/0344f65))
- **sdlc:** capture writes now abort on failure instead of reporting false success ([7bccfa9](https://github.com/whimzyLive/nightshift-ai/commit/7bccfa9))
- **sdlc:** add NA-98.md to the plan-slice corpus-expectation snapshot ([fbed421](https://github.com/whimzyLive/nightshift-ai/commit/fbed421))
- **sdlc:** exclude the capture staging root from the workspace-integrity guard ([00973fa](https://github.com/whimzyLive/nightshift-ai/commit/00973fa))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.7 (2026-08-04)

### 🩹 Fixes

- **sdlc:** drop inert SessionEnd hook timeout, document real budget lever ([a280648](https://github.com/whimzyLive/nightshift-ai/commit/a280648))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.6 (2026-08-04)

### 🩹 Fixes

- **sdlc:** give the SessionEnd hooks a timeout and unbreak the release changelog ([86329cb](https://github.com/whimzyLive/nightshift-ai/commit/86329cb))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.5 (2026-08-04)

### 🚀 Features

- **sdlc:** NA-81 add plan-slice.sh — arg handling, worktree resolution, eval-safe emitter, fence-aware phase/checklist extraction ([8ef32c2](https://github.com/whimzyLive/nightshift-ai/commit/8ef32c2))
- **sdlc:** NA-93 add loop-decide.sh — the loop decision table as a deterministic script ([bc40593](https://github.com/whimzyLive/nightshift-ai/commit/bc40593))
- **sdlc:** NA-91 release the top-level session at PR raise ([30ec1fb](https://github.com/whimzyLive/nightshift-ai/commit/30ec1fb))
- **sdlc:** add bounded-reads pointer to the QA fix-loop contract ([67fe982](https://github.com/whimzyLive/nightshift-ai/commit/67fe982))
- **sdlc:** add bounded-reads pointer to the PE dispatch contract ([cebdf1b](https://github.com/whimzyLive/nightshift-ai/commit/cebdf1b))
- **sdlc:** add bounded-reads clause to the domain-agent handoff ([21e25f3](https://github.com/whimzyLive/nightshift-ai/commit/21e25f3))
- **sdlc:** add context-reuse clause, phase ledger and reuse observability ([f3353f4](https://github.com/whimzyLive/nightshift-ai/commit/f3353f4))
- **sdlc:** re-encode self-generated artifact templates with encoding contract ([88a953d](https://github.com/whimzyLive/nightshift-ai/commit/88a953d))
- **sdlc:** NA-86 P4+P5 — pseudocode conversion, rationale extraction, ADR 0017, CI wiring ([406c3c4](https://github.com/whimzyLive/nightshift-ai/commit/406c3c4))
- **sdlc:** NA-86 P4 tasks 4.1-4.7 — assert-workspace-clean.sh, playbook + agent lazy loading ([a432aa0](https://github.com/whimzyLive/nightshift-ai/commit/a432aa0))
- **sdlc:** NA-86 S2 — loop.md fast path, auto.md epic split, shared AI-Workflow ladder ([a782762](https://github.com/whimzyLive/nightshift-ai/commit/a782762))
- **sdlc:** NA-86 unpad plugin tables and prettier-ignore plugins/sdlc ([eee87f1](https://github.com/whimzyLive/nightshift-ai/commit/eee87f1))

### 🩹 Fixes

- **sdlc:** repair gh-cli error table and dangling doc pointer ([00f512d](https://github.com/whimzyLive/nightshift-ai/commit/00f512d))
- **sdlc:** fix 9 defects found by the max-effort review of PR #226 ([#226](https://github.com/whimzyLive/nightshift-ai/issues/226))
- **sdlc:** trim loop.md back to the plan-slice-budget.test.sh G-14b pin ([0f2e994](https://github.com/whimzyLive/nightshift-ai/commit/0f2e994))
- **sdlc:** fix 6 critical QA defects in the loop/plan-slice/ADR surface ([1e458b6](https://github.com/whimzyLive/nightshift-ai/commit/1e458b6))
- **sdlc:** single-quote resolve-ai-workflow-mode.sh output so Full Auto survives eval ([3bd10b0](https://github.com/whimzyLive/nightshift-ai/commit/3bd10b0))
- **sdlc:** NA-81 bound G-18's item-1 extraction to the Procedure section ([a6cea7b](https://github.com/whimzyLive/nightshift-ai/commit/a6cea7b))
- **sdlc:** NA-93 H-Gate-2 must compare DECISION too, not RULE alone ([d08fb4e](https://github.com/whimzyLive/nightshift-ai/commit/d08fb4e))
- **sdlc:** NA-93 stop run_case swallowing its own ok/bad diagnostics into captured output ([1b45251](https://github.com/whimzyLive/nightshift-ai/commit/1b45251))
- **sdlc:** NA-92 expand flat brace alternation in docs-sync-gate scopes ([1958e71](https://github.com/whimzyLive/nightshift-ai/commit/1958e71))
- **sdlc:** NA-92 make return-contract key mentions unique in the offload refs ([11517c7](https://github.com/whimzyLive/nightshift-ai/commit/11517c7))
- **sdlc:** NA-91 invert the session boundary to opt-in (SDLC_BOUNDARY_ON) ([e857e72](https://github.com/whimzyLive/nightshift-ai/commit/e857e72))
- **sdlc:** NA-91 tighten session-boundary assertion (b) to match the row, not the bare token ([d2273fe](https://github.com/whimzyLive/nightshift-ai/commit/d2273fe))
- **sdlc:** make artifact-encoding.test.sh fence tracking nesting-aware ([#209](https://github.com/whimzyLive/nightshift-ai/issues/209))
- **sdlc:** repair writing-specs template fence closed 87 lines early ([b0e2fb9](https://github.com/whimzyLive/nightshift-ai/commit/b0e2fb9))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.4 (2026-07-28)

### 🩹 Fixes

- **sdlc:** add Step 6.5 change-size gate's fifth bucket to Step 8's report template ([#193](https://github.com/whimzyLive/nightshift-ai/issues/193))
- **sdlc:** qualify remaining bare cross-slice §N refs, add slice-consistency guard ([09d06eb](https://github.com/whimzyLive/nightshift-ai/commit/09d06eb))
- **sdlc:** split docs-pipeline.md monolith into mode-scoped slices ([3ff79ef](https://github.com/whimzyLive/nightshift-ai/commit/3ff79ef))
- **sdlc:** add failing regression test pinning the docs-pipeline.md split (NA-79) ([ad3dafc](https://github.com/whimzyLive/nightshift-ai/commit/ad3dafc))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.3 (2026-07-28)

### 🩹 Fixes

- **sdlc:** replace -p allowlist with denylist, close case-2 gaps (NA-78) ([cbba73f](https://github.com/whimzyLive/nightshift-ai/commit/cbba73f))
- **sdlc:** close QA round-2 minors on NA-78 project-key guard ([6f17288](https://github.com/whimzyLive/nightshift-ai/commit/6f17288))
- **sdlc:** close QA round-1 findings on NA-78 project-key guard ([58c2f56](https://github.com/whimzyLive/nightshift-ai/commit/58c2f56))
- **sdlc:** resolve Jira project key from project-context in refine-feature (NA-78) ([72b74f5](https://github.com/whimzyLive/nightshift-ai/commit/72b74f5))
- **sdlc:** pin failing regression test for hardcoded --project ET literal (NA-78) ([7ed4582](https://github.com/whimzyLive/nightshift-ai/commit/7ed4582))
- **scripts:** fix remaining site-guard consistency gaps from round-1 re-review ([bf34d46](https://github.com/whimzyLive/nightshift-ai/commit/bf34d46))
- **scripts:** close review gaps in the acli site-guard coverage ([9ef6a72](https://github.com/whimzyLive/nightshift-ai/commit/9ef6a72))
- **scripts:** guard acli calls against the global active-site defect ([ce4e2ea](https://github.com/whimzyLive/nightshift-ai/commit/ce4e2ea))
- **scripts:** add failing regression test for acli global-active-site guard ([6f5f672](https://github.com/whimzyLive/nightshift-ai/commit/6f5f672))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.2 (2026-07-25)

### 🚀 Features

- **sdlc:** remove dead principal-engineer/qa-engineer agent defs ([c163812](https://github.com/whimzyLive/nightshift-ai/commit/c163812))
- **sdlc:** memory v2 collection contract, frontmatter lint, and protocol refs ([cdadf4e](https://github.com/whimzyLive/nightshift-ai/commit/cdadf4e))
- **sdlc:** add dangling doc-link check to docs audit reference-integrity tier ([#163](https://github.com/whimzyLive/nightshift-ai/issues/163))

### 🩹 Fixes

- **sdlc:** NA-73 review fixes — inline playbook parity, lint gaps, legacy ADR visibility ([f123c73](https://github.com/whimzyLive/nightshift-ai/commit/f123c73))
- **sdlc:** correct dangling-link check ordering, root-absolute targets, and example depth ([3c11e89](https://github.com/whimzyLive/nightshift-ai/commit/3c11e89))
- **sdlc:** restore deleted docs-pipeline.md sanitization subsection ([8b4b1a1](https://github.com/whimzyLive/nightshift-ai/commit/8b4b1a1))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## Unreleased

### 🚨 Breaking Changes

- **sdlc:** remove the `principal-engineer` and `qa-engineer` agent types — `plugins/sdlc/agents/principal-engineer.md` and `plugins/sdlc/agents/qa-engineer.md` are deleted (NA-75). Both were undispatchable tombstones: Claude Code's one-level subagent-nesting limit already forced both roles onto the inline playbooks (`refs/principal-engineer-playbook.md`, `refs/qa-engineer-playbook.md`, run inline by `/impl`, `/auto`, `/review`), so no consumer could ever dispatch either agent definition directly. The roles themselves are unaffected — they continue to run inline via their playbooks; this only removes the two dead agent-definition files a consumer could have referenced or attempted to dispatch directly.

## 0.45.1 (2026-07-21)

### 🚀 Features

- **sdlc:** add plain-repo fixture B + docs-sync fixture harness (NA-65 P4) ([6f5870d](https://github.com/whimzyLive/nightshift-ai/commit/6f5870d))
- **sdlc:** add artifact-repo dispatch-and-snapshot fixture C (NA-65 P3) ([a20e0db](https://github.com/whimzyLive/nightshift-ai/commit/a20e0db))
- **sdlc:** add product-reference dispatch-and-snapshot fixture + generator (NA-65 P2) ([6d758ca](https://github.com/whimzyLive/nightshift-ai/commit/6d758ca))
- **sdlc:** de-leak doc-types/docs-pipeline and activation-gate reference rows (NA-65 P1) ([db188e5](https://github.com/whimzyLive/nightshift-ai/commit/db188e5))

### 🩹 Fixes

- **sdlc:** wire docs-sync fixture harness into CI, drop informative comments, fix stale §3 crossref ([b1868e8](https://github.com/whimzyLive/nightshift-ai/commit/b1868e8))
- **sdlc:** close 5 docs-pipeline audit generation defects ([#152](https://github.com/whimzyLive/nightshift-ai/issues/152))
- **sdlc:** drop removed gh --yes flag from auto-merge-pr.sh (NA-45) ([2b41727](https://github.com/whimzyLive/nightshift-ai/commit/2b41727))

### ❤️ Thank You

- Rushi Patel @whimzyLive

## 0.45.0 (2026-07-20)

### 🚀 Features

- **sdlc:** forbid informative code comments, route context to memory (NA-48) ([a827464](https://github.com/whimzyLive/nightshift-ai/commit/a827464))
- **sdlc:** NA-47 transition story to Done after Full Auto merge ([1f6039c](https://github.com/whimzyLive/nightshift-ai/commit/1f6039c))
- **nx-release:** NA-63 wire nx release config + register plugins ([8f89968](https://github.com/whimzyLive/nightshift-ai/commit/8f89968))
- **sdlc:** NA-62 add check-plugin-docs-format.sh all-files Prettier gate ([a52bb2a](https://github.com/whimzyLive/nightshift-ai/commit/a52bb2a))
- **sdlc:** NA-61 re-scope stale template-frontmatter rationale + pin audit join key ([aa25c48](https://github.com/whimzyLive/nightshift-ai/commit/aa25c48))
- **sdlc:** NA-61 emit title/description/related-adrs in all four writing-docs templates ([6ef4c51](https://github.com/whimzyLive/nightshift-ai/commit/6ef4c51))
- **sdlc:** NA-60 offer the additional-keys field on init fresh-write (AC1) ([fa2754f](https://github.com/whimzyLive/nightshift-ai/commit/fa2754f))
- **sdlc:** NA-60 compute + print the out-of-scope key warning in docs release ([f2a40c8](https://github.com/whimzyLive/nightshift-ai/commit/f2a40c8))
- **sdlc:** NA-60 add out-of-scope key warning contract to docs-pipeline ref ([0ab1ef7](https://github.com/whimzyLive/nightshift-ai/commit/0ab1ef7))
- **sdlc:** NA-57 strike grep-B residue in docs-pipeline + doc-types ([4a37a3c](https://github.com/whimzyLive/nightshift-ai/commit/4a37a3c))
- **sdlc:** NA-57 re-key knowledge-engineer dispatch selector on mode+type ([3b498d6](https://github.com/whimzyLive/nightshift-ai/commit/3b498d6))
- **sdlc:** NA-57 make seed adr + distill live routes in docs.md ([95073ca](https://github.com/whimzyLive/nightshift-ai/commit/95073ca))
- **sdlc:** NA-57 relocate ADR command-layer flow + guards into adr-pipeline ref ([00863d2](https://github.com/whimzyLive/nightshift-ai/commit/00863d2))
- **sdlc:** NA-56 replace story-branch-missing WARNING with the merged-commit path ([caadaf8](https://github.com/whimzyLive/nightshift-ai/commit/caadaf8))
- **sdlc:** NA-56 honour the post-QA inline sync variant in knowledge-engineer ([50ae0dd](https://github.com/whimzyLive/nightshift-ai/commit/50ae0dd))
- **sdlc:** NA-56 insert Step 6.5 post-QA docs sync into the playbook ([2076f41](https://github.com/whimzyLive/nightshift-ai/commit/2076f41))
- **sdlc:** NA-56 add post-QA sync variant + dual diff source to docs-pipeline ref ([55d090c](https://github.com/whimzyLive/nightshift-ai/commit/55d090c))
- **sdlc:** NA-55 add the audit dispatch branch to knowledge-engineer ([59b89f1](https://github.com/whimzyLive/nightshift-ai/commit/59b89f1))
- **sdlc:** NA-55 promote audit to a live mode in docs.md ([d028d3d](https://github.com/whimzyLive/nightshift-ai/commit/d028d3d))
- **sdlc:** NA-55 add audit-mode contract to docs-pipeline ref ([e8a4d1e](https://github.com/whimzyLive/nightshift-ai/commit/e8a4d1e))
- **sdlc:** NA-55 strike audit from the stub set and rename the shared manifest gate ([1dae8d9](https://github.com/whimzyLive/nightshift-ai/commit/1dae8d9))
- **sdlc:** NA-54 add seed dispatch branch to knowledge-engineer ([a5b6119](https://github.com/whimzyLive/nightshift-ai/commit/a5b6119))
- **sdlc:** NA-54 add the seed behavioural contract to /sdlc:docs ([dc3095f](https://github.com/whimzyLive/nightshift-ai/commit/dc3095f))
- **sdlc:** NA-54 add seed-mode contract to docs-pipeline ref ([45628f3](https://github.com/whimzyLive/nightshift-ai/commit/45628f3))
- **sdlc:** NA-54 strike seed from the stub set and rename the shared manifest gate ([3ffe14d](https://github.com/whimzyLive/nightshift-ai/commit/3ffe14d))
- **sdlc:** NA-53 add release dispatch branch to knowledge-engineer ([96fe74a](https://github.com/whimzyLive/nightshift-ai/commit/96fe74a))
- **sdlc:** NA-53 promote /sdlc:docs release to a live mode ([9202867](https://github.com/whimzyLive/nightshift-ai/commit/9202867))
- **sdlc:** NA-53 add release-mode contract to docs-pipeline ref ([08d86ae](https://github.com/whimzyLive/nightshift-ai/commit/08d86ae))
- **sdlc:** add /sdlc:docs command + sync mode ([c9080ca](https://github.com/whimzyLive/nightshift-ai/commit/c9080ca))
- **sdlc:** ship doc-type registry + docs-manifest scaffold ([8c64308](https://github.com/whimzyLive/nightshift-ai/commit/8c64308))
- **writing-docs:** add Diátaxis doc-authoring skill to sdlc plugin ([9786198](https://github.com/whimzyLive/nightshift-ai/commit/9786198))
- **sdlc:** wire ADR index into domain-agent read/write paths ([756b600](https://github.com/whimzyLive/nightshift-ai/commit/756b600))
- **sdlc:** sanction founder-gated distill deletion as Exception 2 ([0f8964e](https://github.com/whimzyLive/nightshift-ai/commit/0f8964e))
- **sdlc:** add knowledge-engineer agent and /sdlc:adr command ([cda66eb](https://github.com/whimzyLive/nightshift-ai/commit/cda66eb))
- **sdlc:** add writing-adrs skill to sdlc plugin ([f4250c4](https://github.com/whimzyLive/nightshift-ai/commit/f4250c4))
- **sdlc:** orchestrator worktree + flag-gated agent reuse in qa playbook ([094a69c](https://github.com/whimzyLive/nightshift-ai/commit/094a69c))
- **sdlc:** orchestrator-owned worktree in principal-engineer playbook ([3b42188](https://github.com/whimzyLive/nightshift-ai/commit/3b42188))
- **sdlc:** add worktree-gc safety net to SessionEnd hook ([ca41ab4](https://github.com/whimzyLive/nightshift-ai/commit/ca41ab4))
- **sdlc:** run worktree-gc from session-complete cleanup ([70034e6](https://github.com/whimzyLive/nightshift-ai/commit/70034e6))
- **sdlc:** add merged-only worktree-gc.sh reclamation ([4afeaf2](https://github.com/whimzyLive/nightshift-ai/commit/4afeaf2))
- **sdlc:** add idempotent per-story worktree-setup.sh ([2cecf16](https://github.com/whimzyLive/nightshift-ai/commit/2cecf16))
- **sdlc:** enforce project-skill loading in domain-agent dispatches ([#69](https://github.com/whimzyLive/nightshift-ai/issues/69))
- **sdlc:** prettier format-write pass on SessionEnd ([bd0ff3e](https://github.com/whimzyLive/nightshift-ai/commit/bd0ff3e))
- **skills:** NA-15 add atomic-design skill and register in skills-map ([5434ec5](https://github.com/whimzyLive/nightshift-ai/commit/5434ec5))
- **sdlc:** document ai-enablement-engineer, /sdlc:analyze, vendored-skill provenance ([3a88641](https://github.com/whimzyLive/nightshift-ai/commit/3a88641))
- **sdlc:** wire ai-enablement-engineer opt-in into /sdlc:init ([b14f174](https://github.com/whimzyLive/nightshift-ai/commit/b14f174))
- **sdlc:** add /sdlc:analyze command ([b1089fc](https://github.com/whimzyLive/nightshift-ai/commit/b1089fc))
- **sdlc:** add ai-enablement-engineer domain agent ([62140e4](https://github.com/whimzyLive/nightshift-ai/commit/62140e4))
- **sdlc:** vendor skill-creator's support directories for runtime completeness ([9b02ea3](https://github.com/whimzyLive/nightshift-ai/commit/9b02ea3))
- **sdlc:** add analyze-protocol.md shared ref for NA-12 ([9240f2c](https://github.com/whimzyLive/nightshift-ai/commit/9240f2c))
- **sdlc:** vendor skill-creator and find-skills for NA-12 (AC-6) ([383c882](https://github.com/whimzyLive/nightshift-ai/commit/383c882))
- **sdlc:** scrum-master decompose honours AI-Workflow label mode ([de1a400](https://github.com/whimzyLive/nightshift-ai/commit/de1a400))
- **sdlc:** AI-Workflow label fallback for mode resolution in /auto ([469bc78](https://github.com/whimzyLive/nightshift-ai/commit/469bc78))
- **sdlc:** add "Refresh skills" option to the re-init flow ([523eb3e](https://github.com/whimzyLive/nightshift-ai/commit/523eb3e))
- **sdlc:** publish stack skills and wire skills-map sources ([676af5c](https://github.com/whimzyLive/nightshift-ai/commit/676af5c))
- **sdlc:** make the refine phase idempotent (no re-overwrite) ([cd7a8b1](https://github.com/whimzyLive/nightshift-ai/commit/cd7a8b1))
- **sdlc:** defect guards + plan-doc-existence review-fix gate; v0.22.0 ([c9f511a](https://github.com/whimzyLive/nightshift-ai/commit/c9f511a))
- **sdlc:** scrum-master bug template + Agile Bug Template ref ([315b2b4](https://github.com/whimzyLive/nightshift-ai/commit/315b2b4))
- **sdlc:** WORK_KIND-derived branch prefix + defect debugging variant ([7c62b22](https://github.com/whimzyLive/nightshift-ai/commit/7c62b22))
- **sdlc:** triage emits WORK_KIND defect/feature classification ([7c05d76](https://github.com/whimzyLive/nightshift-ai/commit/7c05d76))
- **sdlc:** add Review Gate per-phase review control ([df67653](https://github.com/whimzyLive/nightshift-ai/commit/df67653))
- **sdlc:** add claude-superpowers in-session review agent ([079e94e](https://github.com/whimzyLive/nightshift-ai/commit/079e94e))
- **sdlc:** pragmatic comment policy for domain engineers ([5c336fe](https://github.com/whimzyLive/nightshift-ai/commit/5c336fe))
- **sdlc:** /auto lightweight goes straight to impl (no plan doc) ([6fe3801](https://github.com/whimzyLive/nightshift-ai/commit/6fe3801))
- **sdlc:** /init merge path backfills missing template tokens ([922691d](https://github.com/whimzyLive/nightshift-ai/commit/922691d))
- **sdlc:** /init prompts for review agent and trigger ([f8ed61d](https://github.com/whimzyLive/nightshift-ai/commit/f8ed61d))
- **sdlc:** add SessionEnd hook that cleans session .tmp artifacts ([8616ab0](https://github.com/whimzyLive/nightshift-ai/commit/8616ab0))
- **sdlc:** default new repos to claude-inline review agent ([e722492](https://github.com/whimzyLive/nightshift-ai/commit/e722492))
- **sdlc:** configurable review agent for the tail loop ([5bf497b](https://github.com/whimzyLive/nightshift-ai/commit/5bf497b))
- **sdlc:** scan repo stack in /init and generate tailored setup ([004057e](https://github.com/whimzyLive/nightshift-ai/commit/004057e))
- **sdlc:** add /sdlc:init project scaffolder command ([50b3cdc](https://github.com/whimzyLive/nightshift-ai/commit/50b3cdc))
- **sdlc:** configurable Copilot review mode (none | on-create | on-update) ([0b611bb](https://github.com/whimzyLive/nightshift-ai/commit/0b611bb))
- **sdlc:** emit epic-gated marker on the worker-alternate suspend path ([62e0b8d](https://github.com/whimzyLive/nightshift-ai/commit/62e0b8d))
- **sdlc:** drive all stories in an epic via /auto ([58ed59f](https://github.com/whimzyLive/nightshift-ai/commit/58ed59f))
- **sdlc:** unify loop via native /loop tail + on-clean hook (Option B) ([b0d1b4e](https://github.com/whimzyLive/nightshift-ai/commit/b0d1b4e))
- **sdlc:** loop-after-raise + Full-Auto auto-merge ([359eda7](https://github.com/whimzyLive/nightshift-ai/commit/359eda7))
- **sdlc:** /loop drives Copilot review-fix to completion ([#12](https://github.com/whimzyLive/nightshift-ai/pull/12))
- **scrum-master:** stamp AI-Ready label, points and AI Workflow on decompose-created stories ([#11](https://github.com/whimzyLive/nightshift-ai/pull/11))
- **sdlc:** warn on plugin version drift at session start ([f9239c0](https://github.com/whimzyLive/nightshift-ai/commit/f9239c0))
- **sdlc:** add raise-pr.sh — atomic PR create + ready + reviewer request ([031b126](https://github.com/whimzyLive/nightshift-ai/commit/031b126))
- **sdlc:** sequence sub-task commits within /impl on the story branch ([f2d6265](https://github.com/whimzyLive/nightshift-ai/commit/f2d6265))
- **sdlc:** honour story sub-tasks in /refine-issue ([1b1fdf9](https://github.com/whimzyLive/nightshift-ai/commit/1b1fdf9))
- **sdlc:** session-scoped .tmp handling ([1bd93f2](https://github.com/whimzyLive/nightshift-ai/commit/1bd93f2))
- **sdlc:** add /triage command for lightweight impl routing ([b9b4b6c](https://github.com/whimzyLive/nightshift-ai/commit/b9b4b6c))
- **sdlc:** bundle 4 generic workflow scripts ([e2c16bb](https://github.com/whimzyLive/nightshift-ai/commit/e2c16bb))
- **sdlc:** bundle 12 generic skills ([9fdf96f](https://github.com/whimzyLive/nightshift-ai/commit/9fdf96f))
- **sdlc:** add 7 generic ref playbooks/templates ([c4794d5](https://github.com/whimzyLive/nightshift-ai/commit/c4794d5))
- **sdlc:** add 10 generic SDLC commands ([c81bd89](https://github.com/whimzyLive/nightshift-ai/commit/c81bd89))
- **sdlc:** add 11 generic agent profiles ([c2c7f41](https://github.com/whimzyLive/nightshift-ai/commit/c2c7f41))
- **sdlc:** SessionStart hook injects consumer project-context ([6c62bd5](https://github.com/whimzyLive/nightshift-ai/commit/6c62bd5))

### 🩹 Fixes

- **sdlc:** NA-47 harden auto-merge-pr.sh transition robustness ([d1f4c0b](https://github.com/whimzyLive/nightshift-ai/commit/d1f4c0b))
- **sdlc:** reconcile plugin agent Conventions with code-comments-policy (NA-48) ([5657388](https://github.com/whimzyLive/nightshift-ai/commit/5657388))
- **sdlc:** NA-47 QA polish — angle-bracket placeholder + direct-transition note ([40eac28](https://github.com/whimzyLive/nightshift-ai/commit/40eac28))
- **sdlc:** NA-62 PR#131 review — derive empty-set guard from the gate's own enumeration ([#131](https://github.com/whimzyLive/nightshift-ai/issues/131))
- **sdlc:** NA-62 PR#131 review — spec.md/plan.md acli blocks: preserve list membership ([#131](https://github.com/whimzyLive/nightshift-ai/issues/131))
- **sdlc:** NA-62 PR#131 review — restore loop.md CI-b marker logic shattered by the sweep ([#131](https://github.com/whimzyLive/nightshift-ai/issues/131))
- **sdlc:** NA-62 manually dedent spec.md/plan.md acli blocks to stable Prettier fixed points ([9aa7952](https://github.com/whimzyLive/nightshift-ai/commit/9aa7952))
- **sdlc:** NA-61 close unfilled-placeholder gap PR #129 review caught (regression) ([#129](https://github.com/whimzyLive/nightshift-ai/issues/129))
- **sdlc:** NA-60 trigger the out-of-scope warning on LIKELY_KEYS, not OUT_OF_SCOPE ([#127](https://github.com/whimzyLive/nightshift-ai/issues/127))
- **sdlc:** NA-57 address PR #125 review — 3 plausible findings (NA-57) ([#125](https://github.com/whimzyLive/nightshift-ai/issues/125))
- **sdlc:** NA-57 rewire stale commands/adr.md path references in docs-pipeline.md ([bea4374](https://github.com/whimzyLive/nightshift-ai/commit/bea4374))
- **sdlc:** NA-56 address PR #123 review — fence corruption + inert merged-commit sync ([#123](https://github.com/whimzyLive/nightshift-ai/issues/123))
- **sdlc:** NA-55 address PR #121 review round 1 — count-agnostic gate + garbled audit scope ([#121](https://github.com/whimzyLive/nightshift-ai/issues/121))
- **sdlc:** address PR #119 review round 1 (6/6 accepted) ([#119](https://github.com/whimzyLive/nightshift-ai/issues/119))
- **sdlc:** NA-53 fix llms.txt write blocker + STOP-message polish ([23556f8](https://github.com/whimzyLive/nightshift-ai/commit/23556f8))
- **sdlc:** NA-53 address round-2 review findings (10/10 accepted) ([44088df](https://github.com/whimzyLive/nightshift-ai/commit/44088df))
- **sdlc:** address PR #115 inline review round 3 (NA-52) ([#115](https://github.com/whimzyLive/nightshift-ai/issues/115))
- **sdlc:** restore verbatim first-turn Skill-tool load marker in knowledge-engineer agent ([#115](https://github.com/whimzyLive/nightshift-ai/issues/115))
- **sdlc:** branch docs-sync agent contract + harden diff-base refs ([70f4fa4](https://github.com/whimzyLive/nightshift-ai/commit/70f4fa4))
- **sdlc:** resolve PR #113 review round 2 findings on NA-51 docs scaffold ([#113](https://github.com/whimzyLive/nightshift-ai/issues/113))
- **sdlc:** resolve QA findings on NA-51 doc-type registry + init.md ([f0dd6ab](https://github.com/whimzyLive/nightshift-ai/commit/f0dd6ab))
- **writing-docs:** trim over-limit description, clarify ADR-check parenthetical ([12144e8](https://github.com/whimzyLive/nightshift-ai/commit/12144e8))
- **sdlc:** repair inline code spans wrapped across lines in ADR refs ([5fc2013](https://github.com/whimzyLive/nightshift-ai/commit/5fc2013))
- **sdlc:** PR #108 round-2 findings — payload contract, ADR numbering/branch races, QA tagging, doc staleness ([#108](https://github.com/whimzyLive/nightshift-ai/issues/108))
- **sdlc:** flip confirmed ADRs to accepted, drop bad-slug literal, document --distill focus ([275761e](https://github.com/whimzyLive/nightshift-ai/commit/275761e))
- **sdlc:** resolve review round 2 findings in writing-adrs skill ([#106](https://github.com/whimzyLive/nightshift-ai/issues/106))
- **sdlc:** resolve immutability contradiction and bump plugin version for writing-adrs ([9737ee6](https://github.com/whimzyLive/nightshift-ai/commit/9737ee6))
- **sdlc:** NA-25 third review round — omission-rule wording, load-order softening, guard hardening ([bbd4666](https://github.com/whimzyLive/nightshift-ai/commit/bbd4666))
- **sdlc:** NA-25 QA fix — scrum-master fence corruption + guard fail-fast ([61f217f](https://github.com/whimzyLive/nightshift-ai/commit/61f217f))
- **sdlc:** NA-25 convert agent frontmatter skill preloads to first-turn Skill-tool loads ([#76337](https://github.com/whimzyLive/nightshift-ai/issues/76337))
- **sdlc:** NA-25 add failing guard against frontmatter skill preloads ([#76337](https://github.com/whimzyLive/nightshift-ai/issues/76337))
- **sdlc:** worktree-setup Case 2/3 stdout leak + gc path-scope gate ([1f425ed](https://github.com/whimzyLive/nightshift-ai/commit/1f425ed))
- **sdlc:** NA-27 impl.md acli comment block survives prettier ([e510d80](https://github.com/whimzyLive/nightshift-ai/commit/e510d80))
- **sdlc:** NA-27 review-fix round — worktree GC race, gate false-green, provisioning cases ([#72](https://github.com/whimzyLive/nightshift-ai/issues/72))
- **sdlc:** NA-27 QA fix round — worktree isolation, GC safety, guard fixes ([b725425](https://github.com/whimzyLive/nightshift-ai/commit/b725425))
- **sdlc:** keep isolation worktree inline-code span on one line ([e7cb077](https://github.com/whimzyLive/nightshift-ai/commit/e7cb077))
- **sdlc:** drop hardcoded ## Project skills heading in principal-engineer.md background reference ([b247be7](https://github.com/whimzyLive/nightshift-ai/commit/b247be7))
- **sdlc:** resolve PR #70 review contradictions in Skills-loaded enforcement prose ([#70](https://github.com/whimzyLive/nightshift-ai/issues/70))
- **sdlc:** dedent playbook Skills-loaded failure consequence to parent-bullet scope ([b507250](https://github.com/whimzyLive/nightshift-ai/commit/b507250))
- **sdlc:** extract Skills loaded field and fix playbook indentation ([d4d1721](https://github.com/whimzyLive/nightshift-ai/commit/d4d1721))
- **skills:** NA-15 address review — mobile-engineer domain, quick-ref comment, eval 3 consistency ([8a3ea09](https://github.com/whimzyLive/nightshift-ai/commit/8a3ea09))
- **sdlc:** strip remaining remote font loads from vendored eval-report templates ([8671211](https://github.com/whimzyLive/nightshift-ai/commit/8671211))
- **sdlc:** branch-before-commit, base-branch token, Active-gate, dedup analyze protocol ([a0e61ff](https://github.com/whimzyLive/nightshift-ai/commit/a0e61ff))
- **sdlc:** reword ai-enablement-engineer as order-free, not concurrency-free ([782fa8c](https://github.com/whimzyLive/nightshift-ai/commit/782fa8c))
- **sdlc:** unquote Segoe UI in viewer.html inline styles to avoid attribute termination ([d7b1df9](https://github.com/whimzyLive/nightshift-ai/commit/d7b1df9))
- **sdlc:** make ai-enablement-engineer parallel-capable, fix override contradiction, harden eval-viewer ([a684a88](https://github.com/whimzyLive/nightshift-ai/commit/a684a88))
- **sdlc:** slot ai-enablement-engineer into remaining dispatch ladders ([c2b9477](https://github.com/whimzyLive/nightshift-ai/commit/c2b9477))
- **sdlc:** slot ai-enablement-engineer into dispatch ladder, define Active ([6086c34](https://github.com/whimzyLive/nightshift-ai/commit/6086c34))
- **sdlc:** drop story-points auto-stamping — report estimate for manual entry ([6667eee](https://github.com/whimzyLive/nightshift-ai/commit/6667eee))
- **sdlc:** guard jq parses and trim field-name list in jira-set-field.sh ([02d3022](https://github.com/whimzyLive/nightshift-ai/commit/02d3022))
- **sdlc:** deterministic exit codes + single-call field-name probing in jira-set-field.sh ([6bf5ea0](https://github.com/whimzyLive/nightshift-ai/commit/6bf5ea0))
- **sdlc:** enforce no-overwrite stamping with --if-empty in jira-set-field.sh ([6652ad5](https://github.com/whimzyLive/nightshift-ai/commit/6652ad5))
- **sdlc:** replace nonexistent acli --custom-field flag with REST helper ([d373cc0](https://github.com/whimzyLive/nightshift-ai/commit/d373cc0))
- **sdlc:** third-round review fixes — arg normalization + safe refresh swap ([7af2b0a](https://github.com/whimzyLive/nightshift-ai/commit/7af2b0a))
- **sdlc:** second-round code-review fixes for skill scaffolders + refresh ([8065251](https://github.com/whimzyLive/nightshift-ai/commit/8065251))
- **sdlc:** address code-review findings on the skill install flow ([#36](https://github.com/whimzyLive/nightshift-ai/issues/36))
- **sdlc:** drop skill-name normalization — directory name is authoritative ([8f4dcbb](https://github.com/whimzyLive/nightshift-ai/commit/8f4dcbb))
- **sdlc:** normalize downloaded skill identity to skills-map name ([523b5df](https://github.com/whimzyLive/nightshift-ai/commit/523b5df))
- **sdlc:** actually install confirmed skills during /init ([d8e43cc](https://github.com/whimzyLive/nightshift-ai/commit/d8e43cc))
- **sdlc:** enforce >=2-options invariant across batched AskUserQuestion calls ([fc21ee3](https://github.com/whimzyLive/nightshift-ai/commit/fc21ee3))
- **sdlc:** guard skills picker + preserve base-branch override ([3fc4270](https://github.com/whimzyLive/nightshift-ai/commit/3fc4270))
- **sdlc:** guard init base-branch picker against single-candidate crash ([24016f3](https://github.com/whimzyLive/nightshift-ai/commit/24016f3))
- **sdlc:** align acli skill to no-fallback doctrine + guard ambiguous resume sender ([49d0576](https://github.com/whimzyLive/nightshift-ai/commit/49d0576))
- **sdlc:** make acli the only Jira transport and stop false resume-authority refusals ([00f6bd2](https://github.com/whimzyLive/nightshift-ai/commit/00f6bd2))
- **sdlc:** thread WORK_KIND through /impl; tidy QA supplier list + review fetch ([88f008c](https://github.com/whimzyLive/nightshift-ai/commit/88f008c))
- **sdlc:** defect final-report heading reads Fix not Feature ([ebf93b3](https://github.com/whimzyLive/nightshift-ai/commit/ebf93b3))
- **sdlc:** epic-queue children list fails when acli --fields returns null array ([5d92e71](https://github.com/whimzyLive/nightshift-ai/commit/5d92e71))
- **sdlc:** make the impl/QA playbooks genuinely plan-optional on lightweight ([#24](https://github.com/whimzyLive/nightshift-ai/issues/24))
- **sdlc:** story-points read survives JQL index lag / transient errors ([4b5c2e6](https://github.com/whimzyLive/nightshift-ai/commit/4b5c2e6))
- **sdlc:** resolve script dir safely on slash-less invocation ([ce6a852](https://github.com/whimzyLive/nightshift-ai/commit/ce6a852))
- **sdlc:** scoped-only .tmp cleanup; harden key guard; non-fatal resolve ([b2a4730](https://github.com/whimzyLive/nightshift-ai/commit/b2a4730))
- **sdlc:** correctness fixes in claude-inline review loop ([c90ff55](https://github.com/whimzyLive/nightshift-ai/commit/c90ff55))
- **sdlc:** detect runtime and commit scopes for tailored agent overrides ([537edbd](https://github.com/whimzyLive/nightshift-ai/commit/537edbd))
- **sdlc:** link decomposed stories to Epic at create time ([b0f3d6c](https://github.com/whimzyLive/nightshift-ai/commit/b0f3d6c))
- **sdlc:** derive copilot-reviewed-any from review count + tolerate uppercase mode ([562c97f](https://github.com/whimzyLive/nightshift-ai/commit/562c97f))
- **sdlc:** epic-queue GATE=STOP on acli error + O(N) blocker resolution ([f34849c](https://github.com/whimzyLive/nightshift-ai/commit/f34849c))
- **sdlc:** /loop waits for a Copilot re-review only while one is in progress ([cfe5d28](https://github.com/whimzyLive/nightshift-ai/commit/cfe5d28))
- **sdlc:** gate clean-exit on Copilot CHANGES_REQUESTED + review fixes ([cdc9223](https://github.com/whimzyLive/nightshift-ai/commit/cdc9223))
- **sdlc:** robust mode probe + auto-merge error handling (review) ([b513ad0](https://github.com/whimzyLive/nightshift-ai/commit/b513ad0))
- **sdlc:** guard Workflow A delegated phases against nested session release ([1ce1937](https://github.com/whimzyLive/nightshift-ai/commit/1ce1937))
- **sdlc:** apply triage ref inline in /auto and /impl — no nested session release ([d94b23d](https://github.com/whimzyLive/nightshift-ai/commit/d94b23d))
- **sdlc:** make drift-check pipelines self-guarded, not if-context-dependent ([3400566](https://github.com/whimzyLive/nightshift-ai/commit/3400566))
- **sdlc:** raise-pr.sh — distinguish unverifiable reviewer check from absent reviewer ([c2f7dae](https://github.com/whimzyLive/nightshift-ai/commit/c2f7dae))
- **sdlc:** clarify per-phase sub-task commit scoping + use session temp dir in PR-body example ([f6fc1eb](https://github.com/whimzyLive/nightshift-ai/commit/f6fc1eb))
- **sdlc:** use subTaskIssueTypes() JQL for robust sub-task detection ([8315be1](https://github.com/whimzyLive/nightshift-ai/commit/8315be1))
- **sdlc:** guard SDLC_SESSION_KEY against path traversal ([3979ac5](https://github.com/whimzyLive/nightshift-ai/commit/3979ac5))
- **sdlc:** address review — triage STOP handling + stale docs ([4026525](https://github.com/whimzyLive/nightshift-ai/commit/4026525))
- **sdlc:** resolve plugin paths in subagents via .sdlc-plugin-root marker ([caf069d](https://github.com/whimzyLive/nightshift-ai/commit/caf069d))
- **sdlc:** strip erroneous ./ before absolute CLAUDE_PLUGIN_ROOT paths ([d819807](https://github.com/whimzyLive/nightshift-ai/commit/d819807))

### ❤️ Thank You

- Rushi Patel @whimzyLive
