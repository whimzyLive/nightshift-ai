# Docs pipeline

Shared resolve → diff → regen → draft → founder-confirm → write → commit/PR protocol for
`/sdlc:docs sync`, referenced by both `agents/knowledge-engineer.md` and `commands/docs.md` so the
contract lives in exactly one place. Neither file re-inlines this logic — both summarize and link
back here. Mirrors `refs/adr-pipeline.md`'s shape (copy the skeleton; do not abstract a shared ref
between the two — same "copy the shape, do not generalize" rule `doc-types.md` and Epic NA-50 both
state).

## 1. Purpose + ownership note

This is the single-source pipeline for `/sdlc:docs`. All writes land under paths resolved from the
consumer repo's `.claude/project/docs-manifest.md` (row `target-path`s) and, where the manifest is
silent, `.claude/project/project-context.md`. In this SDLC repo itself, a plugin-authoring write
(touching `plugins/**`) stays within the `ai-enablement-engineer` write-scope — see the Active-guard
scope note in the agent's First steps.

## 2. Two-phase dispatch (split across the confirmation boundary)

A dispatched subagent runs to completion and returns — it cannot pause for interactive human
input. So the founder-confirmation gate cannot live inside the `knowledge-engineer` dispatch; it
lives at the **command layer**, between two separate dispatches of the same agent. This is the
same split `refs/adr-pipeline.md` §2 and `/sdlc:analyze`'s scan-then-apply flow use.

**Phase 1 — compute & draft, writes nothing:**

1. Resolve `.claude/project/docs-manifest.md`. (The command layer already gated on its presence
   before dispatching — see §6 — so phase 1 always has a manifest to read.)
2. Resolve `STORY_BRANCH` — `git fetch origin --quiet`, then `origin/feat/<STORY-KEY>` preferred,
   `origin/fix/<STORY-KEY>` fallback. (The command layer already resolved this before dispatching —
   see §7 — so phase 1 receives `STORY_BRANCH` as an input, it does not re-resolve it.)
3. Compute `CHANGED_FILES` (`git diff --name-only "origin/<BASE-BRANCH>...$STORY_BRANCH"`) and
   `CHANGED_DIFF` (`git diff "origin/<BASE-BRANCH>...$STORY_BRANCH"`) — both from the same
   three-dot range, against the **remote-tracking** base ref (see §7) — never the bare local
   `<BASE-BRANCH>`, whose local checkout may be stale relative to `origin`.
4. Resolve affected rows against the [source-of-truth map](#3-deterministic-regen-algorithm) — for
   each **enabled** manifest row whose registry `trigger` contains `sync`, determine whether it is
   affected per its keying kind (path / content / always).
5. For each affected `auto` row, produce the deterministic regen content (see §3). `llms-txt`
   regenerates every run (AC4).
6. For each affected `how-to` row, draft a refresh of the how-to page(s) whose `source:`
   frontmatter intersects `CHANGED_FILES` (see §5), using the `writing-docs` skill.
7. Return to the command layer: the deterministic regen summary + content, the `llms.txt` content,
   and the narrative how-to drafts. **Nothing is written to disk in phase 1.**

**Founder-confirmation gate (command layer, NOT the agent — see §2's opening paragraph and
`commands/docs.md`).**

- Present the deterministic regen summary (informational — auto rows are not gated) and each
  narrative how-to draft (gated). The founder may accept/edit/reject each narrative draft.
- The gate is **skipped** when there are zero narrative drafts — the run proceeds straight to
  phase 2.

**Phase 2 — write confirmed, fresh dispatch:**

Phase 2 is a fresh subagent dispatch with no visibility into phase 1's return or the gate that ran
in between — the command MUST pass it the deterministic content **and** the founder-confirmed
narrative drafts **verbatim** (including any founder edits), inline in the dispatch prompt or via
session temp-dir files passed by path (per `${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh`, the same
pattern `refs/adr-pipeline.md` §2 uses). Phase 2 writes what the founder saw; it never re-drafts.

8. Check out a branch cut from the **story branch head** (`$STORY_BRANCH`, not `<BASE-BRANCH>` —
   see §7) — the tree must contain the changed source the regen read.
9. Write the deterministic regen content, the regenerated `llms.txt`, and the founder-confirmed
   narrative drafts, each under its manifest-resolved `target-path`.
10. If `git status --porcelain` on the written target paths is **empty** (deterministic output was
    byte-identical to what's already committed, and no narrative draft was confirmed) → no commit,
    no PR, exit cleanly (AC6). Otherwise commit via `conventional-commit`, push, and open or update
    the sync PR (see §7).

## 3. Deterministic regen algorithm

For each **enabled** manifest row whose registry `trigger` contains `sync`, look up its registry
row in `refs/doc-types.md` and resolve whether it is **affected** this run per the source-of-truth
map below. The **keying** column states whether a row is matched against the name-only
`CHANGED_FILES` list, against hunks in the unified `CHANGED_DIFF`, or is always affected:

| Doc-type            | `generation-mode` | Keying  | Affected when…                                                                                                       |
| ------------------- | ----------------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `command-reference` | auto              | path    | `CHANGED_FILES` contains any `commands/**` file                                                                      |
| `agent-reference`   | auto              | path    | `CHANGED_FILES` contains any `agents/**` file                                                                        |
| `skill-reference`   | auto              | path    | `CHANGED_FILES` contains any `**/SKILL.md`                                                                           |
| `config-reference`  | auto              | path    | `CHANGED_FILES` contains `.claude/project/project-context.md` or a config template under `refs/*-template.md`        |
| `hooks-contract`    | auto              | content | a name-matched `.claude/settings*.json` or referenced hook script has hunks in `CHANGED_DIFF` touching a hooks block |
| `error-reference`   | auto              | content | a name-matched command/agent/ref file has hunks in `CHANGED_DIFF` touching an "Error Handling" / error-table section |
| `llms-txt`          | auto              | always  | **every run** (AC4)                                                                                                  |
| `how-to`            | draft-for-review  | path    | `CHANGED_FILES` intersects an existing how-to page's `source:` frontmatter glob-list (see §5)                        |

For each affected row, regenerate its reference-doc set **deterministically** into the row's
manifest `target-path` — this is a prose algorithm executed inline by the dispatched agent, not a
committed script (matches the ADR index-regen algorithm in `refs/adr-pipeline.md` §10 and the
plugin's "instructions not code" style). **Idempotent**: re-running with no source change yields
byte-identical output.

1. **`command-reference`** — for each `commands/**` file, parse its frontmatter (`description`)
   and body; emit one reference page per command, structured identically (one entry per
   symbol/command, consistent shape), under `target-path`.
2. **`agent-reference`** — same, one page per `agents/**` file.
3. **`skill-reference`** — same, one page per `**/SKILL.md`'s frontmatter (`name`, `description`).
4. **`config-reference`** — parse `.claude/project/project-context.md` plus any `refs/*-template.md`
   config templates; emit a single reference page enumerating the config surface.
5. **`hooks-contract`** — parse the hooks block of `.claude/settings*.json` plus any referenced hook
   script; emit a single reference page describing the hook contract (trigger, matcher, command).
6. **`error-reference`** — aggregate every "Error Handling" / error-table section across
   commands/agents/refs into one reference page, one entry per scenario/behaviour row.
7. **`llms-txt`** — see §6's format; regenerated every run regardless of whether any other row was
   affected (AC4).
8. **`how-to`** — NOT part of this deterministic step; affected how-to pages are drafted (not
   auto-written) per §5/§2 step 6, and only written after founder confirmation.

Regeneration for each `auto` row overwrites only the pages derived from files it found affected —
it never touches an unaffected row's pages, and it never touches `how-to` pages (draft-for-review,
gated).

## 4. Voice/format resolution

Narrative drafting (the `how-to` refresh drafts) resolves voice and output format via
`writing-docs`'s chain, never hardcoded: `.claude/project/docs-manifest.md` "Voice & format"
section → `.claude/project/project-context.md` → a stated plain-Markdown, neutral-voice default
when neither is present or silent on a point. See `plugins/sdlc/skills/writing-docs/SKILL.md`
"Voice, Craft, and Output Format" for the full resolution rule and the craft rules that apply
regardless of which source resolves it.

## 5. `source:` refresh convention

Restated here verbatim (normative source: `docs/superpowers/specs/NA-52.md` "`source:` frontmatter
convention") so pipeline readers see it alongside the drafting flow, and so it is not duplicated
inconsistently between this ref and the how-to template it governs:

- **Key name:** `source` (a top-level YAML frontmatter key on a how-to page).
- **Value:** a YAML list of repo-root-relative **glob** strings identifying the source files whose
  change should trigger a refresh draft of this page.
- **Match semantics:** a how-to page is **affected** iff at least one entry in its `source:` list
  matches at least one path in `CHANGED_FILES` under standard glob semantics (`*` within a path
  segment, `**` across segments). Matching is against the name-only changed-file set — it is a
  path-keyed row (see §3's table).
- **Absent key:** a how-to page with **no** `source:` frontmatter is **never** auto-refreshed by
  `sync`. This is the deliberate opt-in boundary — authoring/opting a page in is a founder action
  (add `source:`), not something `sync` infers.
- The template that emits this key at authoring time lives in
  `plugins/sdlc/skills/writing-docs/SKILL.md`'s how-to structure template — see that file for the
  exact emitted shape (a one-line inline comment plus the `source:` glob list).

## 6. No-op / change-gate semantics

- **Manifest-absent silent no-op (AC5).** If `.claude/project/docs-manifest.md` is absent, the
  command layer never dispatches `knowledge-engineer` at all — no branch, no dispatch, no PR, no
  error, **no stdout**, exit 0. This is a command-layer gate (`commands/docs.md`), not something
  phase 1 checks — phase 1 is never invoked in this case.
- **Story-branch-missing WARNING, never a silent success.** If neither `origin/feat/<STORY-KEY>`
  nor `origin/fix/<STORY-KEY>` exists, the command layer emits the explicit WARNING (see
  `commands/docs.md`) and exits — never a silent clean exit that could read as "docs already
  current." v1 sync is branch-diff-only; post-merge sync is deferred to NA-55.
- **Commit/PR only on actual content change (AC6).** Phase 2 step 10 (§2) is the single point that
  decides this: an empty `git status --porcelain` on the written target paths means no commit, no
  PR — a clean, deterministic re-run is a no-op by construction.
- **`llms.txt` regenerated every run, committed only if changed (AC4 + AC6).** `llms-txt` is always
  affected (§3's table), so its content is always recomputed — but §2 step 10's change-gate still
  applies: if the recomputed content is byte-identical to what's committed, it contributes nothing
  to the `git status --porcelain` diff and is not part of the commit.

## 7. Branch / PR naming + control flow

| Item              | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Branch            | `docs/sync-<STORY-KEY>`, cut from the **story branch head** (`origin/feat/<STORY-KEY>`, fallback `origin/fix/<STORY-KEY>`) — **not** `<BASE-BRANCH>`. The story branch carries the changed source the deterministic regen must read; branching off base would regenerate from a tree missing those changes.                                                                                                                                                                                                                    |
| Commit            | `docs(docs): sync <STORY-KEY> reference docs` (via `conventional-commit`)                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| PR title          | `docs(docs): sync <STORY-KEY>`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| PR base           | `<BASE-BRANCH>` from project-context (never assume `main`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Diff source (v1)  | `CHANGED_FILES=$(git diff --name-only "origin/<BASE-BRANCH>...$STORY_BRANCH")` and `CHANGED_DIFF=$(git diff "origin/<BASE-BRANCH>...$STORY_BRANCH")`, both from the same `origin/<BASE-BRANCH>...$STORY_BRANCH` three-dot range, against the **remote-tracking** base ref (checkout-independent — a stale local base never skews the diff), after `git fetch origin --quiet`. Dual diff-source selection (story-branch-vs-develop **vs** merged-commit) is out of scope — deferred to NA-55.                                   |
| First-run PR      | Create the branch, commit, push, open the PR (`gh pr create`) against `<BASE-BRANCH>`.                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Re-run behaviour  | **Open or update** (AC6): before creating, check whether `docs/sync-<STORY-KEY>` already exists on `origin` (`git rev-parse --verify origin/docs/sync-<STORY-KEY>` / `gh pr list --head docs/sync-<STORY-KEY>`). If it does → check it out, **`git reset --hard` onto the freshly regenerated state** (the branch content is fully derived, so a hard reset is safe and keeps history clean), then **`git push --force-with-lease`** to update the existing open PR — never open a duplicate PR.                               |
| Control-flow tail | Mirror `commands/adr.md`: after the PR is raised, drive the review loop to convergence via `/loop /sdlc:loop <PR_URL>` (falling back to `ScheduleWakeup` if the harness cannot nest `/loop`). If the run ended **before** any PR, release directly via `${CLAUDE_PLUGIN_ROOT}/scripts/session-complete.sh` — this covers the manifest-absent silent no-op, the story-branch-missing WARNING, a usage STOP, and a clean "nothing changed" no-op alike (all four release without a PR; only the manifest-absent path is silent). |

## 8. llms.txt format (v1 decision)

`llms-txt` regenerates at the `llms-txt` row's manifest `target-path` (registry default `llms.txt`,
repo-root) deterministically on every run: an **index-only** file (no full-content `llms-full.txt`
in v1), grouping the generated pages of every enabled, `public: yes` manifest row by Diátaxis
quadrant, each entry a `title — one-line description — relative link` line derived from the
generated page's frontmatter. Idempotent, no narrative synthesis. This matches the `llms-txt` row's
`source-of-truth` cell in `refs/doc-types.md` — see that cell for the authoritative wording rather
than restating it here; `refs/doc-types.md`'s own Registry self-check section is what keeps that
cell's wording singular within that file.

## 9. Cross-reference

The registry (`refs/doc-types.md`) and the manifest template (`refs/docs-manifest-template.md`)
are read, not owned, by this pipeline — `sync` never edits either. The `writing-docs` skill
(`plugins/sdlc/skills/writing-docs/SKILL.md`) owns the how-to structure template (including the
`source:` frontmatter emission, §5 above) and the voice/format resolution chain (§4 above) — this
ref restates the pieces `sync` depends on but does not re-inline the full skill.
