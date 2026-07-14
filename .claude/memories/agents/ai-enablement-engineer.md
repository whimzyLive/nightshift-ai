# ai-enablement-engineer — memory

## NA-6 — content-writer agent + voice-rules ref + /gtm:site command (`plugins/gtm`)

- A plan's structural verification grep can accidentally match its own explanatory prose. The
  NA-6 plan's Task 3 check `grep -cF '.claude/.gtm-plugin-root' plugins/gtm/commands/site.md`
  expects `0` to prove "no accidental agent resolver block" — use `-F` (fixed-string) on the full
  marker path: an unescaped-dot regex (`grep -c '.gtm-plugin-root'`) matches any char before the
  token and counts unrelated prose. Also: a sentence merely _explaining_ "there is no
  `.claude/.gtm-plugin-root` resolver block here" trips the count — when a verification grep
  detects a structural artifact, don't name the artifact's literal marker in nearby prose; name the
  _mechanism_ generically ("no plugin-root resolver block"). Always run the check for real rather
  than eyeballing the regex.
- The gtm plugin's shared-gate boundary (`copy-editing` lives only on the command's gate step, never
  on the content-producing agent's `skills:` list) is easy to verify precisely: grep the file for
  the skill name and manually confirm the hit sits in prose ("deliberately not on this list") rather
  than inside the `skills:` YAML block — a bare occurrence count doesn't distinguish the two.
- When a spec's plugin-root convention differs by artifact type (commands get
  `${CLAUDE_PLUGIN_ROOT}` natively; agents resolve it via a `.claude/.<plugin>-plugin-root` marker
  file), copy the agent-side resolver header block **verbatim** from the established pattern file
  (here, `product-marketing-manager.md`) rather than re-deriving it — a byte-diff against the
  source is the cheapest verification and the plan expects verbatim reuse, not a rephrase.
- This story's worktree started on a synthetic `worktree-agent-<hash>` local branch one commit
  behind `origin/feat/NA-6` (the plan-writer's commit hadn't been merged into this worktree's local
  ref yet). `git checkout feat/NA-6` failed because that branch was already checked out in a
  sibling worktree (`git worktree list` showed it). Fix: `git merge --ff-only origin/feat/NA-6` on
  the current branch — safe since the local ref was a strict ancestor — rather than trying to force
  a branch switch that git's one-worktree-per-branch rule disallows.

## NA-4 — per-channel ownership picker (`plugins/gtm`)

- `plugins/gtm/refs/*.md` protocol refs are thin and delegate fully to the `postiz` CLI — never
  hand-roll HTTP. New refs (e.g. `channel-config.md`) should mirror `postiz-verify.md` /
  `product-detect.md`: an intro line naming which `/gtm:init` step applies them, then concrete
  sections (no TBDs), ending in an error-handling table the calling command step can defer to
  instead of re-specifying inline.
- `marketing-context-template.md` deliberately keeps its own `<...>` placeholder tokens throughout
  (e.g. `<name>`, `<one-liner>`) as a _documented convention_ for "value inserted at write time" —
  when grepping for stray placeholders across gtm refs/commands, these pre-existing tokens (and
  prose that mentions `` `<...>` `` descriptively) are expected noise, not drift. Only flag a
  genuinely new/unintended `<...>` token introduced by an edit.
- When a command step (e.g. `/gtm:init` Step 4b) is written to _defer_ to a ref for enum/error
  detail rather than restate it, don't expect a verification grep for that enum text to also match
  in the command file — that's by design (single source of truth lives in the ref), not
  inconsistency.
- Multi-file plans in this plugin (ref + template + command) hinge on keeping enum lists, defaults,
  and table column order byte-identical across all three files — do the verification greps
  (Task 4-style) as the last step even when confident; cheap and catches transcription drift early.

## NA-4 review-fix follow-up

- `marketing-context-template.md`'s `## Template` fence is _rendered verbatim_ into every generated
  `.claude/project/marketing-context.md` — never put writer-facing meta-instructions (empty-list
  exception prose, enum catalogues, anything with an `${CLAUDE_PLUGIN_ROOT}`-style unresolvable
  reference) inside that fence. Only actual template markup belongs there; explanatory prose about
  the template goes below the closing fence, near `## Schema` or folded into the matching
  `## Fill rules` entry — don't duplicate the same rule in two places, extend the existing Fill
  rule instead.
- When a Step-6-style summary line lists "this unblocks story X, Y, Z" and the very story this run
  implements is itself one of X/Y/Z, drop it from the unblocked-list and say its config now exists
  — a blanket "none of their config exists yet" claim placed after a per-run "N configured" line is
  self-contradicting and a reviewer will catch it.

## NA-4 review-fix follow-up (round 2)

- A "verbatim fence" convention is only as safe as its placeholder gate: if the fence's illustrative
  sample rows/values are concrete-looking (not `<...>` tokens), the Fill-rule-1 style gate ("replace
  every `<...>` token") can't catch them leaking into a fresh-run render. Fix pattern: keep the fence
  itself to the true default/empty state (e.g. header + separator row only), and move illustrative
  "here's what a filled example looks like" content _below_ the closing fence, explicitly labeled
  illustrative (near `## Schema`, not folded into the fence). Illustrative example rows may still use
  the `<id>` convention for cells that are always run-generated — that's consistent with the rest of
  the template's placeholder style and with the plan's verification grep (`grep -v '<id>'`).
- When a parenthetical cites "a downstream story" by describing its function (not its key), and that
  description turns out to match the very story doing the current edit, don't just note the story is
  self-referential — check what the _actual_ downstream consumer is (grep sibling Fill rules/schema
  rows for the same concept) and reword the parenthetical to name that real downstream capability
  (e.g. "voice overrides / content strategy") instead of leaving a self-referential description in place.
- Meta-instructions to the _executor_ (e.g. "note X here" / "remember to include Y") must never sit
  inside a print-verbatim blockquote meant for the _end user_ — even a single parenthetical line. Pull
  it out as a plain instruction sentence immediately before the `Print a summary:` cue, not as another
  line inside the `>` block.
- When one step's instruction is phrased as an unconditional loop ("for each channel, prompt...") but
  a sibling step (e.g. Step 0's Merge path) already carves out an exception (only prompt genuinely new
  items), add a short forward-pointing clause at the unconditional step rather than assuming the
  reader will infer the exception from the other step alone — cross-step conditionals need an explicit
  breadcrumb at both ends.

## NA-4 review-fix follow-up (round 3)

- Never assume a CLI's documented/skill-modeled output shape (e.g. "returns a JSON array, pipe
  straight to `jq`") is what actually comes out on stdout — a human-readable preamble line before
  the JSON is a common real-world CLI pattern. When a ref delegates enumeration to a CLI, make the
  parse defensive (extract from the first line starting with the expected structural character,
  e.g. `sed -n '/^\[/,$p'`) and give the "zero exit but nothing parseable" case its own distinct
  STOP message — folding it into the transport/connection-error message misdiagnoses a CLI-version
  or output-format problem as a backend-reachability problem, sending the founder down the wrong
  troubleshooting path.
- A "refresh only the stable-identity field on re-run match" rule is incomplete if a _display_
  field (e.g. `Name`) also participates in the fallback match key — display data still needs
  refreshing every run, or a later rename silently breaks the fallback the _next_ time the primary
  key goes stale. When a rule like this changes, update it in every place it's stated (ref
  re-run-matching bullet, template schema column note, template fill rule, command step if it
  restates) — don't leave one copy saying "only field X" after another now says "X and Y".
  Explicitly note in the ref when a later fix deliberately supersedes wording carried over from an
  earlier merged spec, so a future reader doesn't think it's a transcription slip.
- A step that only _gathers into an in-memory model_ (writes nothing to a final path) must never
  use the verb "write" for what it does with the empty-list case either — "record ... into the
  in-memory model; a later step renders it" keeps the step's own no-write contract intact even for
  its edge cases.
- An "atomic staging guarantee leaves X untouched" claim is only true for the paths _that step's
  own atomic write_ covers. On a Merge/Re-run path, an earlier step (e.g. a marketingskills skill
  invocation) may have already mutated a file _outside_ that atomic write (e.g.
  `.agents/product-marketing.md`) before this step's error occurs — state the STOP's write-nothing
  scope precisely (which file(s) truly weren't touched) and point at how to reconcile the file that
  might already have moved (re-run the command to resync).
- Prefer per-item three-way outcomes (drop / retain-and-flag-stale / abort) over an all-or-nothing
  decline gate whenever one declined item shouldn't cost the founder every other answer already
  gathered in the same run — model the "decline" outcome as an _explicit, distinct_ abort action,
  not the default branch of a single yes/no per affected item.
- `grep -v '<pattern>'` on whole lines silently hides any other match that happens to share a line
  with the excluded pattern. For a "no stray placeholder" style check, scan token-by-token with
  `-o` (`grep -onE '<[^>]+>' files | grep -v ':<line-anchored-exact-token>$'`) so the file:line
  survives and only the exact excluded token is dropped, not the whole line it lives on.
- When the same AC-n label is reused by two different stories in one file (NA-3's Step 0/2/3/4/6
  gates vs NA-4's Step 0-Merge/Step 4b additions), only the _newly added_ citations need the
  disambiguating story prefix (`NA-4 AC-n`) — leave every pre-existing citation as bare `AC-n`.
  Grep `AC-[0-9]` across the file first and sort hits by which story's section they sit in before
  touching any of them; qualifying a pre-existing NA-3 tag by mistake is itself a new inconsistency.
- A boundary condition stated only implicitly (e.g. "pre-selected to X" vs "skipped -> Y") should
  get one explicit sentence distinguishing "prompted and the default was accepted" from "never
  prompted/answered at all" — reviewers read these as the same case unless the text says otherwise.

## NA-5 — KPI metric and source setup (`plugins/gtm`)

- When a plan/spec's Task-4-style verification grep expects a multi-word token (e.g. `Custom
command`) to appear verbatim on a single line across three files, watch for prose line-wrap:
  Markdown source can hard-wrap a phrase like "Custom command" across two source lines (`Custom` at
  EOL, `command` starting the next), which is invisible when reading rendered Markdown but makes
  `grep -onE 'Custom command'` silently miss it in exactly one of the three files. Run the Task-4
  greps for real (not just by eyeballing the prose) and re-wrap any option/enum list so each locked
  token phrase sits fully on one physical line.
- When a spec gives an exact illustrative table (e.g. the `## KPI` nine-row example with concrete
  values like "GitHub stars" / "managed" / "128" rather than `<...>` placeholders) and says "add
  this exact shape to the fenced template block," follow that literally even though sibling
  sections (Product/Postiz) use `<...>` placeholders in the same fence — the two styles can coexist
  in one template file; add a short inline comment above the table clarifying it's illustrative
  ("row set fixed, values illustrative, source-irrelevant cells blank") so a reader doesn't mistake
  the concrete-looking values for what a fresh run would literally emit.
- A `$<field name>` illustration token (e.g. `$<Auth env var>`, showing how a stored string
  shell-expands a referenced env var by name at probe time) is a legitimate spec-inherited
  convention, not stray placeholder drift — when it appears verbatim in the spec's own locked
  wording, carry it into the ref as-is rather than "fixing" it to a bracket-free form.

## NA-15 — atomic-design skill (published-for-others, `skills/` + `plugins/sdlc/refs/skills-map.yml`)

- This repo's runner has no `pyyaml` preinstalled; a plan/spec YAML-parse verification gate
  (`python3 -c "import yaml..."`) fails with `ModuleNotFoundError` on a clean shell. Fix:
  `python3 -m pip install --quiet --user pyyaml` before running the gate — cheap, one-time, don't
  substitute a regex/grep check instead since the gate specifically wants a real YAML parse.
- Framework-agnostic content scans (AC-4-style, banning `react|vue|expo|...` tokens) must be scoped
  to skill _content_ only (`SKILL.md` + `references/*`), explicitly excluding the sibling
  `skills-map.yml` registration entry — that file legitimately carries the same framework names as
  `when:` detection triggers. Keep the grep's file list narrow rather than grepping the whole skill
  directory, or the registration metadata will produce false-positive "FAIL" hits.
- For a "published-for-others" skill (same class as `hono-api`/`typeorm`/`electrodb`), the negative
  checks that matter are: absent from `.claude/project/skills.json`, no `.claude/skills/<name>/`
  copy, and no agent-override binding — confirmed once per skill; don't add any of the three even if
  a later task seems to imply local consumption. Registration is `plugins/sdlc/refs/skills-map.yml`
  `source`+`path` only.
- When a plan gives an exact YAML block to append to `skills-map.yml` "after the `electrodb` entry,
  before the trailing comment block," insert it verbatim at that exact anchor — the file's trailing
  `# Frameworks / ORMs with no built-in skill suggestion` and `# Agent-to-skill domain mapping`
  comment blocks are documentation-only and don't require updating for a new entry unless the plan
  explicitly asks (it didn't here — left the per-agent summary comment untouched).

## NA-26 — enforce project-skill loading in domain-agent dispatches (`plugins/sdlc/refs` + `agents`)

- This story's dedicated worktree was checked out on a synthetic `worktree-agent-<hash>` branch,
  one commit behind `origin/feat/NA-26` — `git checkout feat/NA-26` failed with "already used by
  worktree at <main-repo-path>" because the main repo checkout (left over from `/sdlc:plan`) still
  held the branch. Fix: confirm the other worktree is clean (`git -C <path> status --short` empty,
  HEAD matches `origin/<branch>` exactly — no uncommitted work to lose), `git -C <path> checkout
<base-branch>` there to free the ref, then `git checkout feat/NA-26` in this worktree. Only do
  this when the other checkout is verified clean; never force-switch a dirty worktree.
- A plan's grep-based verification that expects an exact multi-word phrase ("read each directory
  guide it lists") to survive on one physical line can fail even on a file the plan tells you to
  edit only lightly (add a trailing clause) — if the file's _pre-existing_ prose already hard-wraps
  that phrase across two Markdown source lines, the phrase-preservation check fails through no
  fault of the new edit. Since the plan explicitly names this exact check in its Task 5 Step 4
  verification, re-wrap the existing sentence onto one line while inserting the new clause (cheap,
  in-scope since you're already touching that paragraph) rather than leaving it to fail silently.
- The plan's whole-story check `grep -rn "Behaviour\|behaviour" plugins/sdlc/refs/ plugins/sdlc/agents/
plugins/sdlc/README.md` — "Expected: none" — is written as if the tree starts clean, but this
  repo's plugin already carries plenty of pre-existing British-spelling prose in files/sections the
  story never touches (`triage.md`, `jira-bug-template.md`, `skills-manifest.md`,
  `project-context-template.md`, `solutions-architect.md`, and untouched paragraphs inside files
  this story DOES edit). Read "Expected: none" as "none _introduced by this story's edits_" — diff
  the flagged line numbers against your own edited spans before treating a non-empty grep as a
  failure; don't rewrite unrelated pre-existing prose to force a literal zero-match, that would be
  scope creep beyond the plan's named file/line anchors.
- A 12-file, prose-only contract story (no code, no data model) still benefits from running every
  task's own verification grep individually before the closing whole-story block — the per-task
  greps catch numbering-contiguity regressions (e.g. an inserted list item bumping every later
  number) that the whole-story greps don't check for.

## NA-26 review-fix follow-up

- Same worktree-branch-lock issue recurred, but this time the sibling worktree holding
  `feat/NA-26` (the repo's _main_ worktree) had already fast-forwarded to the branch's true head —
  freeing it via `checkout <base-branch>` there wasn't needed/available. When the dispatched
  worktree's own branch is a strict ancestor of the target branch (`git merge-base --is-ancestor
<local-HEAD> <target-branch>`), `git merge --ff-only <target-branch>` on the current
  worktree-local branch is the lower-risk fix — it never touches the other worktree, can't lose
  uncommitted work there, and leaves you on your own synthetic branch with the right file content
  and history, ready to commit. Reserve force-freeing the other worktree's checkout for when a
  true ff-only isn't possible.
- The playbook's per-sub-bullet consequence text ("On failure → STOP-and-redispatch...") reads as
  attached to only the _last_ sub-bullet under a two-case list unless it's dedented to the parent
  bullet's own paragraph indent (2 spaces under a `- ` top bullet, not 4 spaces continuing a nested
  `- ` sub-bullet). When a reviewer flags "this consequence should apply to both sub-cases,"
  dedenting by exactly the sub-bullet's own indent width (here 2 spaces) turns it back into a
  continuation paragraph of the parent bullet in Markdown's nesting model — no rewording needed.
- The `principal-engineer.md` agent file's prose (`## Collecting results`) and the playbook's
  authoritative rule (`## Step 5`) both name the same 3-vs-4-field return contract independently —
  when a playbook change adds a field to the domain-agent return contract (e.g. `Skills loaded`),
  grep the parallel agent-file prose for the old field count/list too (`grep -n "Extract"
plugins/sdlc/agents/principal-engineer.md`) — it's easy for the spec/plan to fix the playbook
  (source of truth) and miss the agent file's independent restatement of the same contract.

## NA-26 — PR #70 review, round 2 (10 accepted internal-contradiction findings, `plugins/sdlc/refs` + `agents` + `README.md`)

- A single Skills-loaded semantic rule ("what counts as invoked", "pass iff", "blocked exempt",
  "extras tolerated") was independently restated in up to 5 places (handoff Return format, principal
  playbook Step 5, QA playbook Step 3, README enforcement summary, and each of the 6 domain-agent
  profiles). When a reviewer finds a contradiction between two restatements, fixing only the two
  named sites isn't enough — grep every restatement site (`Skills loaded`, `pass iff`, `gate on
starting work`, `Project skills`) across the whole plugin before declaring done; a phrase can drift
  independently in a site the finding didn't name (here: README's summary paragraph, which nobody
  flagged directly but silently restated the pre-fix "none passes only when declared" wording).
- Established a durable "one source of truth + pointers" pattern for this kind of shared mechanical
  rule: principal playbook Step 5 owns the pass/fail mechanics for orchestrator-side verification;
  domain-agent-handoff.md's Return format owns the agent-side `Skills loaded:` semantics (including
  the preloaded-skill and no-instruction-fallback clauses). Every other site (QA playbook, README,
  the 5 sibling agent-profile `## Skills` paragraphs) should be a one-line pointer with only the
  consequence that differs locally (e.g. QA: "return blocked immediately, no redispatch" vs
  principal: "redispatch once then STOP") — never a full re-derivation. `grep -rn "pass iff"` across
  `refs/*.md README.md` after an edit is the cheapest way to confirm only the two source-of-truth
  files still contain the actual mechanics.
- A hardcoded doc-internal heading reference (e.g. "`## Project skills`" naming a specific override
  section heading) breaks the moment a real consumer override uses a different heading for the same
  concept (this repo's own `.claude/project/agents/ai-enablement-engineer.md` uses "## Skills
  (plugin-bundled — invoke via the Skill tool)"). Prefer describing the section by its _role_
  ("the override's skills section — whatever heading it uses, the section listing skills to invoke
  via the Skill tool") over quoting a literal heading string that other repos are free to rename.
- A "STOP-and-redispatch on Skills-loaded failure" rule silently collides with a sibling "zero new
  commits since pre-dispatch HEAD = silent failure" rule when the redispatch targets a phase whose
  code work already landed in the first dispatch — the redispatch produces zero _new_ commits by
  design (only the return-line semantics were wrong, not the code). Fix pattern: scope that specific
  redispatch as a narrow "verify already-committed work against the named skills; fix only if a
  skill mandates a change; re-emit a compliant return" prompt, and explicitly exempt it from the
  zero-new-commits STOP in the same sentence that defines the exemption trigger — don't leave the
  general rule and the exemption in two disconnected paragraphs a reader has to reconcile themselves.
- `git worktree list` showing `feat/NA-26` "locked" (checked out read-only in the repo's main
  worktree, left over from a prior `/sdlc:plan`/`/sdlc:impl` run) with the dispatched worktree
  sitting on a synthetic `worktree-agent-<hash>` branch one merge-commit _ahead_ of
  `origin/feat/NA-26` (a spec PR had merged into main and been merged back into the worktree branch)
  meant neither the prior story's "checkout the target branch" nor "ff-only merge the target into
  local" pattern applied cleanly. Since the task only needs this worktree's branch to fast-forward
  cleanly onto the target for the orchestrator later, `git reset --hard origin/<branch>` on the
  dispatched worktree's own synthetic branch (never on a branch checked out elsewhere) is the
  correct, lowest-risk move when the worktree's local history has _diverged_ from the target
  (not just lagged behind it) and the working tree is otherwise clean — confirm `git status --short`
  is empty before resetting, since `--hard` discards anything uncommitted.

## NA-27 — orchestrator-managed worktree + shared Nx cache + agent-reuse flag (`plugins/sdlc`)

- This story's dispatched worktree had NO `node_modules` at all (not stale — genuinely absent), so
  the very first `git commit` failed on the repo's `husky` pre-commit hook (`lint-staged` binary not
  found), not on anything story-related. `pnpm install --prefer-offline` (no `--frozen-lockfile`
  needed here since the lockfile was already correct) fixed it in ~30s via the shared pnpm store.
  Symptom to recognize fast next time: `ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL … "lint-staged" not
found` on a first commit attempt in a fresh worktree means `node_modules` is missing, not that the
  commit content is wrong — check `ls node_modules/.bin | wc -l` before assuming a real failure.
- A published, multi-repo plugin script that needs a per-repo config value the sibling scripts treat
  as an orchestrator-supplied positional arg (e.g. `<BASE-BRANCH>` in the playbooks/agent docs) can
  instead read it directly from `.claude/project/project-context.md` at runtime when the caller is a
  bare hook/script with no orchestrator handing it in (here: `worktree-gc.sh`, invoked bare from
  `SessionEnd` with zero args). Mirrored `read-review-config.sh`'s `read_token` sed/grep pattern
  (`^\|[[:space:]]*<Token>[[:space:]]*\|` → `[A-Za-z0-9_./-]+` capture, defaulted on read-failure)
  rather than inventing a new one — keeps the "read a single-value token row" convention in one
  recognizable shape across the plugin's scripts, and the `|| true` guards are load-bearing under
  `set -uo pipefail` for the exact same silently-swallow-no-match reason documented there.
- When a plan Task explicitly writes out a script's full case-by-case algorithm (here: Task 1 Step 3,
  the three idempotent worktree-resolution cases with their exact git subcommands per case), transcribe
  it near-verbatim rather than re-deriving the git plumbing — the plan had already resolved subtleties
  (e.g. case 1 fetches/merges via `git -C "$WT"`, not the primary root; case 2/3 fetch via the primary
  root) that are easy to get backwards if you rewrite from the prose summary instead of the literal
  step text.
- A prompt-contract numbered list that gains two new **mandatory first instructions** (cwd + Nx-cache,
  per spec §1/§3) is cleanest inserted as items 1–2 with every existing item renumbered down, rather
  than appended at the end — the spec explicitly calls them "the mandatory first instruction," and
  renumbering only the prose items (not the underlying meaning) is a pure count-shift with no risk of
  changing behavior, so do it directly instead of leaving a `1a`/`1b` insertion that reads oddly.
- For a per-file "mirror the playbook change in the agent doc" task (Tasks 9–10) where the spec's
  Files-changed table gives only a one-line description (not the full worktree/guard bash blocks the
  playbook carries), a condensed prose mirror is the right level of fidelity — the agent-file's own
  header already says "retained as background reference, playbook is source of truth," so duplicating
  every bash snippet there would create a second copy to keep in sync rather than one clean pointer.
- A plan task with an explicit escape hatch ("If no such prose exists, make no change and note it in
  the commit body") should actually take that hatch when true — grepping `plugins/sdlc/commands/
review-fix.md` for both `isolation` and `worktree` came up empty, so Task 8 produced no commit at
  all (an empty `git add` + `git commit` would fail with "nothing to commit"); the plan's own
  Files-changed table description ("inherits the idempotent provision via the QA playbook") was the
  tell that this file's isolation model was always implicit, never spelled out in its own prose.

## NA-27 QA fix round (`plugins/sdlc`)

- This dispatched worktree was one commit behind `origin/feat/NA-27` at start — the task's stated
  base SHA (`bf61700`) didn't match `HEAD` (`730b30c`, the pre-worktree-model spec-merge commit).
  Confirmed via `git branch --contains bf61700` that the local worktree branch was a strict ancestor
  (no divergence), then `git merge --ff-only origin/feat/NA-27` in the worktree brought it current —
  same low-risk pattern as prior stories' worktree-lag fixups, just via `origin/<branch>` fetched
  fresh rather than a sibling worktree's local ref.
- The most subtle finding in this batch (QA playbook Steps 5/6 running `git fetch && git merge
--ff-only` bare, i.e. in the session/primary cwd) only actually corrupts the primary post-NA-27:
  before the worktree model landed, the primary WAS the story branch (the ff-merge was a no-op /
  intentional sync), so the bug was latent until this same story's own worktree-model change made
  the primary sit on `<BASE-BRANCH>` permanently. A structural change to an invariant (here:
  "primary never checks out the story branch") can silently invalidate leftover commands elsewhere
  in the _same_ file that predate the invariant and were never touched by the change's own diff —
  grep the whole playbook file for every bare `git fetch`/`git merge`/`git add`/`git commit` (no
  `-C`) after landing a worktree-isolation change, not just the sections the plan's diff touched.
- Fixing "assert primary status is EMPTY" → "assert primary status matches ITS OWN pre-dispatch
  snapshot" needs the pre-existing-dirt escape hatch stated at the capture site too, not just the
  assert site — otherwise a reader only sees "snapshot, then compare" at the assert and might still
  read the capture-time comment (`# must be empty`) as a precondition the run should enforce. Update
  the comment at the capture line in the same edit as the assert line; don't leave one half of the
  paired instruction using old language.
- `git rev-parse --abbrev-ref HEAD` returning the literal string `"HEAD"` for a detached checkout
  (not empty, not an error) is an easy gate-writing mistake: a `[ -z "$WB" ]` guard reads as if it
  covers "unreadable OR detached," but detached HEAD produces a non-empty value and silently falls
  through to whatever check comes next. Any script deriving a branch name via `--abbrev-ref HEAD`
  needs an explicit `"$WB" = "HEAD"` guard as a _second_, separate condition — never assume the
  empty-check subsumes it.
- `bash -n` only proves parse-validity, not runtime-correctness of shell string-hashing logic (the
  `pnpm-lock.yaml` staleness check added here) — after writing it, trace the four cases by hand
  (missing node_modules / missing hash file / hash match / hash mismatch) rather than relying on
  syntax-check alone, since a portable-CLI script has no test harness in this repo to exercise it.

## NA-27 — external review-fix round on PR #72 (`plugins/sdlc`)

- Dispatched worktree was FIVE commits behind `origin/feat/NA-27` this time (`730b30c`, the
  pre-worktree-model spec-merge commit — the whole worktree-isolation implementation itself was
  missing), not the usual one-commit lag. Same fix pattern held: `git merge-base` confirmed the
  local branch was still a strict ancestor, so `git merge --ff-only feat/NA-27` (the branch ref, not
  `origin/feat/NA-27` — both resolve the same commit here and `git merge` doesn't require exclusive
  checkout, only `git checkout` does) brought the worktree current without touching the sibling
  worktree that had the branch checked out. Don't assume "one commit behind" from prior stories —
  always diff the stated base SHA against actual `HEAD` and `git log base..target` before assuming
  the gap is trivial.
- A GC race-condition fix (finding: guard compares a worktree's HEAD against the CURRENT base tip,
  which drifts once the base branch advances past the worktree's true creation point) is better
  fixed by recording an immutable "provision point" marker at creation time than by trying to make
  the race window narrower. Used **worktree-scoped git config** (`extensions.worktreeConfig true` +
  `git -C "$WT" config --worktree sdlc.provisionSha <sha>`) written ONLY in the two branches that
  actually create a new worktree directory (re-provision-after-teardown and first-run-from-base) —
  never in the reuse/fast-forward branch, since worktree-scoped config persists in that worktree's
  own `.git/worktrees/<name>/config.worktree` across every later idempotent re-invocation of the
  setup script, so re-writing it on reuse would silently reset the very reference point the guard
  depends on. Always keep an old-style fallback check (here: tip-equality against current base) for
  worktrees provisioned before the new guard existed and therefore have no recorded marker.
- A "Case 1 registration probe matches but the directory was removed out-of-band" bug needs the
  registration check split from the case dispatch: compute a boolean (`REGISTERED=...`), insert a
  `[ ! -d "$WT" ]` pre-check between the probe and the `if/elif/else` case chain that prunes the
  stale registration AND flips the boolean back to false, then dispatch on the boolean — this lets
  execution "fall through" cleanly into the branch-exists/create cases without duplicating their
  logic or fighting bash's linear if/elif structure.
- When a spec's package-manager token (`.claude/project/project-context.md` "Package manager" row)
  needs to drive both the install command AND the lockfile name/hash check, resolve it once into two
  paired variables (`INSTALL_CMD`, `LOCK_FILE_NAME`) via a single `case` statement with an explicit
  `*)` fallback that warns to stderr and re-assigns the pnpm defaults — this keeps "unknown token"
  and "pnpm" behaviourally identical (same code path afterward) rather than needing a separate
  guard later in the script.
- A "gate can false-green on untracked leftovers" fix (assert `git status --porcelain` is empty
  before the gate/before each phase's assertion) needs the exact same one-liner duplicated at BOTH
  the QA-playbook Step 6 (pre-gate) and the principal-playbook Step 5 (post-phase-commit) sites —
  they're structurally identical checks guarding different moments (before a shared quality gate vs.
  after every phase dispatch) and a reviewer finding one doesn't imply the other was already fixed;
  grep the whole plugin for `status --porcelain` before declaring a "shared worktree cleanliness"
  finding fully resolved.
- `impl.md`'s `--body "..."` quoted string is printed VERBATIM into the Jira comment, so a naive
  "restore column-0 continuation lines" fix is NOT prettier-stable when that fence sits nested
  inside an indented numbered-list item (`5.` here) — verified the hard way: the first commit's
  `lint-staged` (`prettier --write --ignore-unknown`) actually corrupted the fence (split it into
  two mismatched fences, leaked the quoted body out as bare paragraphs, broke the bash string).
  Root cause, confirmed by minimal repro (`printf` a 2-item list with a fenced block containing a
  dedented vs. indented blank-line continuation and diff `prettier --write` before/after): prettier's
  remark-based Markdown parser requires EVERY line inside a fence nested in a list item — including
  blank-line-separated continuations — to satisfy the item's content indentation (here 3 spaces,
  from `5. `); a column-0 continuation line breaks the parser's list-item/fence association at PARSE
  time, so no post-hoc `<!-- prettier-ignore -->` can glue the split nodes back together (ignore
  comments only suppress re-printing of already-correctly-parsed nodes, they can't fix a mis-parse).
  Re-indenting the continuation to 3 spaces "fixes" prettier-stability but reintroduces the exact
  content-corruption bug being fixed (the leading spaces leak into the literal Jira comment text).
  The actual fix that satisfies both constraints: DEDENT THE WHOLE FENCE OUT OF THE LIST ITEM (fence
  markers and body at column 0, not nested/indented under `5.`) — CommonMark still associates it
  visually with the preceding list item as long as there's no blank-line-terminated topic break, and
  prettier's parser no longer needs to reconcile fence-body indentation against list-item content
  indentation, so it leaves the block completely untouched (verified `diff` before/after `prettier
--write` = empty). **Always verify a Markdown/bash-artifact fix by actually running this repo's
  real `prettier --write` on a scratch copy in the repo's own directory before committing** — testing
  from `/tmp` gave a false "no changes" negative (config/plugin resolution differs outside the repo
  tree), and `git show HEAD:<file>` after commit is the only way to see what `lint-staged` really did
  (it silently re-stages its own output as part of the same commit, past the point your Edit tool
  call can inspect). Do all such scratch-file prettier reproduction testing in a `/tmp`-adjacent
  scratch dir or with an explicit absolute `cd` guard — a bare `cd <primary-repo-root>` in a Bash
  call (rather than the dispatched worktree path) silently runs subsequent commands against the
  PRIMARY checkout, which for a domain agent is a hard violation if anything gets staged/committed
  there; confirm `pwd` and `git worktree list` immediately after any such `cd` before trusting `git
log`/`git status` output.

## NA-27 — Copilot fix round on PR #72 (`plugins/sdlc/scripts`)

- The dispatched worktree's own branch (a synthetic `worktree-agent-<hash>`) was, once again, a
  strict ancestor of `origin/feat/NA-27` (this time five commits behind, at `730b30c` — the
  pre-worktree-model spec-merge point). Same low-risk fix as prior NA-27/NA-26 rounds: `git
merge-base --is-ancestor HEAD feat/NA-27` to confirm no divergence, then `git merge --ff-only
feat/NA-27` (the local branch ref — `feat/NA-27` was checked out exclusively in the sibling
  primary worktree, so only `git checkout` there is blocked, not `git merge`). This is now a
  recurring pattern across at least 3 stories — always diff stated base SHA against actual `HEAD`
  before assuming a fresh worktree is current.
- A two-branch "admits local-OR-remote, but body always fetches/merges origin unconditionally" bug
  (worktree-setup.sh Case 2) is fixed the same way Case 1 already handles it: probe
  `ls-remote --exit-code --heads origin "$BRANCH"` into a boolean ONCE, then gate both the fetch and
  the later ff-only merge on that same boolean, instead of re-deriving remote-existence at each
  call site (which is how the original bug crept in — the `elif` entry condition and the fetch call
  independently assumed "matched the elif => origin has it").
- worktree-gc.sh's `sdlc-*|agent-*` basename-only candidate filter is a classic "matches by name,
  not by identity" gap — the fix is a second `case "$WT" in "$WORKTREES_ROOT"/*) ;; ...` gate right
  after the basename `case`, reusing the already-robustly-resolved `PRIMARY_ROOT` (git
  `rev-parse --show-toplevel`, absolute + symlink-resolved) rather than re-deriving repo root with
  a fresh `pwd`/`readlink` — the worktree paths from `git worktree list --porcelain` are already
  absolute, so a plain `"$WORKTREES_ROOT"/*` glob-case match is sufficient, no extra `realpath`
  needed.
- Verifying a stdout-contract fix (`WORKTREE=`/`NX_CACHE_DIRECTORY=` exactly two lines) doesn't
  require actually running the script end-to-end against a live repo — a full read-through
  confirming every `git`/`fetch`/`worktree add` call in the modified branches carries `>&2` (or was
  already `>&2`), then locating the two unguarded `printf` lines at the very end as the only stdout
  producers, is sufficient and much cheaper than an end-to-end dry run.

## NA-25 — phase 3, failing regression guard for frontmatter `skills:` preloads (`plugins/sdlc/scripts`)

- `.github/workflows/ci.yml` is OUTSIDE this agent's resolved write-scope even when a dispatch
  prompt explicitly names it as a task step. The `analyze-protocol.md#ownership-resolution-rules`
  config-driven AI-config surface whitelists exactly one `.github/*` path
  (`.github/copilot-instructions.md`) — not `.github/workflows/**` — and the workspace→agent table
  has no row for it (`tools/` → platform-engineer is the closest sibling but doesn't cover
  `.github/`). AC-5 ("refuse and abort on any path outside scope, listing the offending path")
  applies even under an orchestrator-authored task list — a dispatch prompt is not itself scope
  expansion or "consent" per the harness-level instruction that no agent message authorizes
  permission/config changes outside a role's own boundaries. When a task bundles an in-scope
  deliverable (a new `plugins/sdlc/scripts/*.sh` guard) with an out-of-scope one (wiring it into
  `.github/workflows/ci.yml`), do the in-scope parts, explicitly refuse+skip the out-of-scope
  write, and surface it back to the orchestrator as a named gap (likely platform-engineer's
  `tools/` domain, or a table addition) rather than silently doing it or silently dropping it.
- A frontmatter-only parse guard (ignore `skills:` mentions in a Markdown file's body/prose) is
  cleanly done with a tiny two-delimiter awk state machine: increment a counter on each `^---$`
  line, print only while between the 1st and 2nd occurrence, `exit` once the 2nd is hit. This
  avoids `sed -n '/^---$/,/^---$/p'`-style ranges misfiring on files whose body later reintroduces
  a bare `---` (e.g. a Markdown horizontal rule), since the awk version stops for good after the
  frontmatter block closes rather than re-opening on every subsequent `---` pair.
- This is a phase-3 "write ONLY a failing regression test, do not fix the bug" dispatch (systematic
  debugging discipline) — resist the pull to also touch the 12 offending agent files even though
  the fix is mechanical and obvious; the fix is a deliberately separate later phase/dispatch.

## NA-25 — phase 4, convert all 12 agents' frontmatter `skills:` to first-turn Skill-tool loads (`plugins/sdlc/agents`)

- The 12 agents split into 3 distinct body-structure families, and each needed a different merge
  strategy rather than one copy-pasted section: (1) the 5 domain-implementer agents
  (database-administrator, mobile-engineer, platform-engineer, sync-engineer, web-engineer) share a
  byte-identical `## Skills` section that already explained frontmatter-preload + override-skill
  ordering — extend that section in place rather than inserting a second "load FIRST" block above
  it, since the instruction to "merge into an existing skills-invocation section" outranks the
  "place prominently near the top" default when the two conflict. (2) principal-engineer,
  qa-engineer, solutions-architect, tech-lead already had a `## Required skills — invoke in order
before any other step` section, but it listed **only a subset** of the frontmatter `skills:` list
  (e.g. principal-engineer's body named 2 of 4 frontmatter skills, qa-engineer's named 3 of 6) —
  the body list must be extended to the FULL frontmatter list in frontmatter order, not left
  partial, since the removed frontmatter was the only place the omitted skills (`acli`, `gh-cli`,
  `subagent-driven-development`, `conventional-commit`) were ever declared. (3) product-manager and
  scrum-master needed the same full-list-extension treatment, plus adding `Skill` to `tools:` (both
  lacked it entirely — Read/Write/Bash or Read/Bash/Edit only). Always diff frontmatter `skills:`
  against the body's already-invoked subset before writing the merge; don't assume an existing
  "Required skills" section is already complete just because it exists.
- scrum-master's existing skills section was a **per-step invocation table** (`user-story-mapping`
  invoked at a specific point in Mode 1, `user-story-splitting` only when a story is >8 pts) — this
  answers _when to apply_ a skill, which is orthogonal to _when to load_ it. The NA-25 workaround
  needs loading to happen in the first turn regardless of when the skill is semantically applied
  later in a multi-mode agent's execution. Fix: keep the table (renamed to describe application
  timing, "loading early does not mean applying early") and prepend a numbered load-first list
  covering all 3 frontmatter skills (including `acli`, which the table never mentioned as an
  invoked skill even though it's the agent's mandatory Jira transport) — this is a genuine merge,
  not a duplicate, because the two blocks answer different questions about the same skill set.
- 6 of the 12 agents (principal-engineer, qa-engineer, solutions-architect, tech-lead,
  product-manager, scrum-master) had `tools:` lists with no `Skill` entry at all — their frontmatter
  `skills:` preload previously made an explicit `Skill`-tool call unnecessary for those skills, so
  nobody had needed to add the tool. Removing frontmatter preloads makes `Skill` load-bearing for
  every one of the 12 agents; grep `tools:.*Skill` across all agent files after any such conversion
  to catch this rather than assuming the 6 files that already had `Skill` (because they also had
  `Write`/`Edit` domain-agents needing it for a different reason) generalize to the rest.
- The regression guard (`check-agent-skill-preloads.sh`, added in phase 3) parses ONLY between the
  first two `^---$` lines, so it is blind to anything in the body — a body section that still says
  "Generic skills are preloaded via frontmatter" after the frontmatter block was actually removed
  would pass the guard while being factually wrong. The guard proves the mechanical fix; it does
  NOT prove the prose was updated to match. Manually verify every body sentence that used to
  describe frontmatter preloading (ai-enablement-engineer's First-steps item 2 had one, each of the
  5 domain-implementer agents' `## Skills` intro sentence had one) was reworded, not just removed
  frontmatter-side.
- This dispatch touches `plugins/sdlc/agents/ai-enablement-engineer.md` — the file that IS this
  agent's own definition, being edited by an instance of the same agent in the same session. No
  special handling needed (it's a normal in-scope write, and the running instance already has this
  turn's skills loaded from its own dispatch), but worth flagging for future dispatches: self-owned
  file edits still go through the identical write-scope check and Edit-tool flow as any other file.

## NA-25 — QA fix round on commit 9d6fc64 (`plugins/sdlc/agents/scrum-master.md` + `plugins/sdlc/scripts`)

- Confirmed root cause of the scrum-master.md corruption: the file's Mode-1 "Execution steps"
  numbered list uses non-standard sub-item markers (`6a.`, `10a.`, `10b.`) that are not valid
  CommonMark ordered-list syntax. `npx prettier --check` on the saved (Edit-tool) content reported
  "All files formatted correctly" — a **false negative**, exactly the trap NA-27's `e510d80` memory
  entry already flagged: the repo's real `lint-staged` pre-commit hook runs `prettier --write`
  during `git commit`, and that invocation produced a different result than my pre-commit
  `--check`. Only `git show <sha> -- <file>` after the commit reveals what actually landed — never
  trust a pre-commit `--check`/`--write` dry run as proof the committed content will match.
  Whatever upstream edit disturbs an ordered list's numbering (here: inserting new content earlier
  in the same file, unrelated to the `10a.`/`10b.` region) can trigger a full-list renumber pass by
  prettier's remark parser that then mis-parses the non-standard sub-markers as plain paragraph
  text, flattening their nested bullets and turning fenced code blocks into corrupted inline spans.
- Fix pattern (same family as `e510d80`, confirmed to generalize): dedent the ENTIRE `10a.`/`10b.`
  pseudo-list-item block — marker, prose, sub-bullets, and fences — to column 0, with blank lines
  separating prose/bullets/fences from each other. This removes ALL ambiguity about whether the
  content is "nested inside" the preceding numbered list item, so prettier's parser has nothing to
  reconcile and leaves the block untouched on every subsequent pass. Verified via a real,
  in-repo-tree `pnpm exec prettier --write` run TWICE in a row: the first pass only trimmed two
  stray leading spaces (cosmetic), the second pass reported `(unchanged)` and produced a byte-
  identical diff — that two-pass "second write is a no-op" check is the actual proof of stability,
  not a single `--check` invocation (which is exactly the false-negative trap above).
- `check-agent-skill-preloads.sh`'s original `agents_dir="$(cd "$here/../agents" && pwd)"` line is
  a classic `set -uo pipefail`-without-`-e` trap: a failed `cd` inside a command substitution does
  NOT stop the script (no `-e`), so `agents_dir` silently becomes an empty string, and the
  subsequent `for f in "$agents_dir"/*.md` glob degrades to `/*.md` (repo root) or, on an empty-but-
  existing dir, to the literal unexpanded glob string (caught by the old `[ -e "$f" ]` per-item
  skip) — both paths fall through to zero offenders and a false "OK" exit 0. Fix: check `[ -d
"$agents_dir" ]` explicitly BEFORE resolving the absolute path (so a missing dir fails loudly
  first), then use `shopt -s nullglob` + an array (`files=("$agents_dir"/*.md)`) instead of the
  bare `for f in .../*.md; do [ -e "$f" ] || continue` idiom — nullglob makes a true zero-match
  glob expand to a genuinely empty array, so `[ "${#files[@]}" -eq 0 ]` reliably distinguishes
  "no files matched" from "one file matched" without relying on the per-item existence-check
  side-effect. This same nullglob-array pattern is worth reusing anywhere else in the plugin that
  still uses the bare `for f in "$dir"/*.ext; do [ -e "$f" ] || continue` idiom to iterate a glob —
  it is silently vacuous on a missing/empty directory, not just fragile.

## NA-7 — `/gtm:docs` docs-SEO audit command + `docs-auditor` agent + rubric (`plugins/gtm`)

- `docs-auditor` is the first `plugins/gtm` agent authored under the NA-25 Skill-tool-loading
  pattern from day one (no frontmatter `skills:` list at all — `content-writer.md` and
  `product-marketing-manager.md`, both pre-NA-25, still carry frontmatter `skills:`). The spec
  said so explicitly ("both loaded via the Skill tool, per the NA-25 resume workaround — not
  relied on via frontmatter preload"), and NA-25's own memory entries document the pattern was
  only ever applied to the 12 `plugins/sdlc/agents/*.md` files, not gtm's. When a new agent's spec
  names the NA-25 pattern by name, follow the sdlc-plugin agents' shape (no `skills:` frontmatter
  field, `tools:` includes `Skill`, a body "## Required skills" section with the exact marker
  sentence) rather than copying the sibling `content-writer.md`/`product-marketing-manager.md`
  frontmatter-`skills:` shape it's dispatched alongside — the two conventions now legitimately
  coexist in the same plugin until a future story converts the older agents.
- `gh pr list --search "head:<prefix>"` (substring/ref match, confirmed by `dep-gate.sh`'s own
  comment in `plugins/sdlc/scripts/dep-gate.sh`) is exactly the right tool for a
  branch-namespace-prefix idempotency probe (`gtm/docs-audit/*`) — `--head` only does exact-match
  and can't express a prefix at all. Paired it with a documented, greppable PR-body convention
  (`- \`<findingId>\` (\`<rubricRef>\`): <summary>`, finding ID = first backtick token on a `- `line) so the command's step-3 idempotency-guard-input enumeration and the agent's step-5
PR-authoring convention stay in lockstep — defined the exact`grep -oE` pattern once in the
  command doc and cross-referenced it (not re-derived) from the agent doc's PR-body instructions.
- A spec's "so init seeds it" phrasing for a new `marketing-context-template.md` block does not
  always mean `commands/init.md` itself needs editing: this story's Config table gives the new
  `Docs audit paths`/`excludes` fields **fixed, non-interviewed defaults** (no founder decision
  point), and `init.md` Step 5 already generically "fills this template from
  `${CLAUDE_PLUGIN_ROOT}/refs/marketing-context-template.md`" — so a template-only edit (new
  section + Schema rows + a Fill rule stating "no interview, always the documented default")
  is sufficient and correctly matches the spec's own New/Modified-files table, which does NOT list
  `commands/init.md` as touched. Verified against the live repo: `.claude/project/marketing-context.md`
  in this worktree predates the story and genuinely lacks the `## Docs audit` block, which is
  exactly the "config predates this story" fallback case `/gtm:docs` step 2 is written to handle
  — confirms the fallback path is real, not speculative, and that this file itself is correctly
  out of this story's write-scope (owned by init runs, not hand-edited by a plugin-authoring story).
- Read the actual `ai-seo` and `content-strategy` marketingskills skill bodies (via the Skill tool)
  before drafting `refs/docs-audit-rubric.md` rather than inferring criteria from the skill names —
  concrete section titles/quotes from those skills (e.g. ai-seo's "40-60 word... snippet
  extraction", "Query Fan-Out", the Princeton GEO citation-boost table; content-strategy's
  "Keyword Research by Buyer Stage") became the rubric's `Source` column citations, which is what
  makes `rubricRef` genuinely traceable (AC-1) instead of a plausible-sounding invention.

## NA-25 — third review round on PR #73 (6 accepted findings: `refs/domain-agent-handoff.md`, `README.md`, all 12 `agents/*.md`, `scripts/check-agent-skill-preloads.sh`)

- A prose passage explaining a mechanism ("frontmatter-preloaded") that a PR itself just removed is
  a self-contradiction a reviewer WILL catch even when the passage isn't in a file the PR's diff
  touched directly — `domain-agent-handoff.md` and `README.md` both independently restated the old
  "frontmatter-preloaded" framing for the `Skills loaded:` omission rule, and neither got updated
  when the 12 agent files were converted in the first fix round. Same lesson as the NA-26 "one
  source of truth restated in N places" pattern: after a mechanism change, `grep -rn
'frontmatter-preload'` (or whatever the old mechanism's name was) across the WHOLE plugin, not
  just the files the task named, before declaring the conversion complete.
- A blanket "FIRST action, before any other work" instruction is too strong when the same agent
  body already has an earlier, load-bearing gate (a step-0 branch-verify STOP, or a nesting
  self-guard) that must run first and can itself early-abort with zero skills loaded — the two
  instructions read as contradictory ("load first" vs "this STOP happens before anything"). Fixed
  by softening the lead-in everywhere to name the ordering relationship explicitly: "Before any
  implementation work — after your pre-flight/step-0 checks, and skipped entirely on an early abort
  — load each of these via the Skill tool". This still satisfies the NA-25 workaround (skills load
  in the same first turn that also runs the pre-flight checks — turn granularity, not instruction
  ordinality, is what defeats the harness re-injection bug), while no longer overriding a
  higher-priority STOP gate. Reusable pattern: when adding a "must happen first" instruction to an
  agent body that might already gate on an early-abort condition, name the interaction explicitly
  rather than leaving two absolute-sounding directives to silently conflict.
- Turning a "consistent marker string for a machine-checkable guard" requirement into an actual
  fix meant treating the marker sentence as a literal contract, not just matching prose: I wrote
  the exact same sentence (`Before any implementation work — ... — load each of these via the Skill
tool:`) into all 12 files, including the 5 "Shape B" agents whose skill list was originally
  written as inline comma-separated prose rather than a numbered list — for those, the marker
  sentence had to end in a colon immediately followed by the backtick-quoted skill list on the SAME
  physical line (not wrapped), since a guard doing `grep -F` needs the literal substring intact on
  one line. Confirmed via `grep -qF "$marker" "$f"` in a real test loop across all 12, and confirmed
  prettier's default `proseWrap` (unset in this repo's `.prettierrc` → "preserve") does not
  re-wrap long unwrapped lines, so writing the marker as one long physical line is stable across a
  real `prettier --write`.
- A regression guard that only checks a NEGATIVE condition ("no frontmatter skills:") can still be
  vacuously satisfied by a file that was simply stripped of frontmatter without ever gaining the
  intended replacement (e.g. someone deletes the `skills:` block but never adds a first-turn load
  section). Pairing it with a POSITIVE check (the file must also contain the load marker) closes
  that gap — test both directions separately in a scratch temp-dir copy (never the real tree): (1)
  delete the marker line from one file → guard must fail on marker-missing; (2) re-add a
  frontmatter `skills:` block to a different file → guard must fail on preload, and can report BOTH
  failure classes together in one run without the second masking the first (used two independent
  offender-accumulator variables + a shared `fail` flag rather than one `exit 1` per check).
- The awk frontmatter-extractor's original 2-delimiter counter had no anchor on the OPENING `---` to
  `NR==1` — a frontmatter-less file whose BODY happens to contain two `---` horizontal-rule lines
  with something matching `^skills:` between them would false-positive, since the awk state machine
  treats the FIRST `---` it sees anywhere in the file as the opener. Fix: split into `NR==1 &&
/^---$/ { open=1; next }` / `NR==1 { exit }` (no frontmatter at all if line 1 isn't the delimiter)
  / `open && /^---$/ { exit }` (closing delimiter) / `open { print }`. Verified with a crafted
  scratch file (no real frontmatter, plain body containing a `---`/`skills:.../---` span) that the
  old unanchored version would have flagged and the anchored version correctly passes.
- Scrum-master's step-10 continuation block (blockquote + fenced bash + bullet list) was indented 8
  spaces under a 4-char `10. ` marker — one indent level too deep for CommonMark list-continuation
  (needs exactly 4, matching the marker width), so it rendered as a literal indented code block
  rather than list-item content. This was PRE-EXISTING content the first two NA-25 fix rounds never
  touched (round 1 only edited the "Required skills" section near the top; round 2 fixed 10a/10b's
  separately-corrupted fences but left step 10's own body alone) — a reviewer eventually caught it
  on a fresh pass over the whole file, not from a diff. Applied the SAME column-0-dedent pattern
  already established for 10a/10b (`61f217f`) rather than trying 4-space re-indentation, for
  consistency and because it's the pattern already proven prettier-stable in this exact file.
  Verified via the same two-pass `prettier --write` idempotence check (both passes report
  `(unchanged)`) plus the `grep -c '```'` = 24 fence-count invariant.
