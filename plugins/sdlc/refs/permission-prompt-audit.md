# Permission-Prompt Audit — why approvals still fire

Audit of skills/agents/settings for instructions + patterns that force a manual
approval prompt, even when "dangerous skip" is believed active.

## Root cause #0 — not actually in bypass mode

- Project `.claude/settings.json` → `"defaultMode": "auto"`.
- Global `~/.claude/settings.json` → `"skipDangerousModePermissionPrompt": true`.

`skipDangerousModePermissionPrompt` only suppresses the **startup warning banner**.
It does NOT bypass per-command permission checks. `auto` mode = auto-approve only
what matches an allow rule; everything else prompts.

True bypass requires one of:

- `"defaultMode": "bypassPermissions"` in settings, OR
- launching `claude --dangerously-skip-permissions`.

In real bypass mode, every block below disappears (all checks skipped). Everything
else in this doc only matters while NOT in bypass.

## Root cause #1 — static analyzer can't parse → can't match allow rule → prompt

The Bash permission matcher statically parses the command. If it can't, it cannot
match an allow rule, so it falls through to ASK. Allowlisting does not help — the
rule never matches. Triggers seen / known:

| Trigger                           | Error / behavior                                        | Source                          |
| --------------------------------- | ------------------------------------------------------- | ------------------------------- |
| Backtick `` `...` ``              | `backtick_body_overrun` "cannot be statically analyzed" | user report                     |
| Command subst `$(...)`            | unanalyzable → prompt                                   | 76 occurrences in agents/skills |
| Quote inside brace exp `{"..."}`  | "expansion obfuscation" HARD block (overrides allow)    | CLAUDE.md                       |
| Unbalanced/nested quotes, heredoc | parse failure → prompt                                  | —                               |
| Inline JSON literal               | combines brace+quote → block                            | CLAUDE.md, acli skill           |

## Root cause #2 — compound + dynamic commands

- Compound chains `a && b ; c | d`: EVERY segment must match an allow rule. One
  unlisted segment → whole line prompts.
- `cd` inside a compound can trigger a prompt (CLAUDE.md note).
- `$VAR` / `$(...)` interpolation in args makes the literal prefix unmatchable for
  some rule shapes → prompt (user report).

## Root cause #3 — paths outside project dir

- `/tmp/*` and `/var/folders/*` Read/Write are not covered by project-scoped allow
  rules → prompt. Evidence: `Read(//tmp/**)` and `rm /tmp/*` had to be hand-added.

## Root cause #4 — allowlist churn from parens in commit scopes

`settings.local.json` holds dozens of one-off rules like
`Bash(git commit -m 'fix\(functions\): ...')`. Conventional-commit scope parens
`fix(functions)` are shell metacharacters; the matcher needs the exact escaped
literal, so **every new commit message is a new prompt**. ~30+ such dead entries.

---

## Offending instructions in agents/skills (file:line)

These instructions actively generate the patterns above:

- `${CLAUDE_PLUGIN_ROOT}/agents/scrum-master.md:74,152,171` — `$(mktemp /tmp/acli-...XXXXXX.json)`
  → command-subst + /tmp (double trigger).
- `${CLAUDE_PLUGIN_ROOT}/agents/scrum-master.md:188` — instructs "Write all descriptions to temp
  files using mktemp" → /tmp by default.
- `.agents/skills/acli/SKILL.md:87,233,237,263` — same `mktemp /tmp/...` guidance,
  taught as the canonical pattern.
- `${CLAUDE_PLUGIN_ROOT}/agents/principal-engineer.md` — heavy `$(...)` usage.
- `.agents/skills/gh-cli/SKILL.md`, `.agents/skills/acli/SKILL.md` — `$(...)` +
  produce `fix(scope):` parenthesised commit messages (churn source).
- Inline ADF JSON to `acli` (already warned in CLAUDE.md, but still taught nearby).

---

## Remediations (ranked)

### R0 — flip to true bypass (eliminates ALL of the above)

Set project `.claude/settings.json` → `"defaultMode": "bypassPermissions"` (or always
launch with `--dangerously-skip-permissions`). Security tradeoff — only do this in
the CI / spare-machine context. This is the single highest-leverage fix.

### R1 — move temp files into project + allowlist (if staying in auto)

- Use `./.tmp/` not `/tmp`. Add to `.gitignore`.
- Allow rules: `Read(./.tmp/**)`, `Write(./.tmp/**)`, `Bash(rm ./.tmp/*)`,
  `Bash(mkdir -p ./.tmp)`.
- **Session-scoped subdir:** plugin temp files go under a per-session subdir via
  `scripts/tmp-dir.sh` (`dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)`, then
  `mktemp "$dir/acli-XXXXXX.json"`). The dir is unique per session in BOTH modes — worker
  → `./.tmp/<SDLC_SESSION_KEY>`, interactive → `./.tmp/<CLAUDE_CODE_SESSION_ID>` (resolved by
  `scripts/session-key.sh`). The `./.tmp/**` allow globs are **recursive**, so they already
  cover nested `./.tmp/<key>/...` — **no new allow rule is required**. Both the `SessionEnd` hook
  (`scripts/cleanup-tmp.sh`) and `scripts/session-complete.sh` remove `./.tmp/<key>` at teardown,
  so an errored or interrupted session leaves nothing behind. macOS: `XXXXXX` must be at end
  after a dot separator.

### R2 — scriptify repeated dynamic shell

Move any command containing `$(...)`, backticks, or compound `&&`/`|` logic into a
committed script under `${CLAUDE_PLUGIN_ROOT}/scripts/*.sh` with a fixed positional-param
interface. The `$(...)` lives INSIDE the script — never on the command line — so the
analyzer sees one matchable invocation. Allow rule: `Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)`.
Candidates: jira-fetch probes, git rev/diff comparisons, exit-marker echoes,
DNS/auth checks (the `S293`/`S294` compound-shell blocks).

### R3 — kill commit-message churn

Write the message into the session-scoped temp dir and commit from there —
`dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh); ...; git commit -F "$dir/msg.txt"`.
Allow rule: `Bash(git commit -F *)`. Removes the per-message paren-escaping prompt and lets the
~30 dead `git commit -m 'fix\(...\)'` rules be deleted. Use the scoped `$dir` (not a bare
`./.tmp/msg.txt`) so teardown removes it with the rest of the session's scratch — cleanup is
scoped-only and does not sweep loose `./.tmp/*` files.

### R4 — never inline JSON / never inline `$()` or backticks on command line

Already in CLAUDE.md for JSON. Extend the rule to: no backticks, no `$(...)`, no
heredoc on the Bash command line — wrap in a script (R2) or write payload to `./.tmp`.
