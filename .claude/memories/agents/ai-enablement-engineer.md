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
