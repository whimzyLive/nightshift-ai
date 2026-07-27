#!/usr/bin/env bash
# no-hardcoded-project-key.test.sh — regression test pinning the `--project ET` literal removal
# (NA-78).
#
# `plugins/sdlc/commands/refine-feature.md` hardcodes `--project ET` in its Epic-creation
# `acli jira workitem create` call. In any repo whose Jira project key is not `ET`, this silently
# misroutes the created Epic into the wrong Jira project — `acli` reports success, so there is no
# error. The fix (a later phase, NOT this test) is for `refine-feature.md` to resolve the key from
# `.claude/project/project-context.md` the same way `agents/scrum-master.md:119`/`:292` already do
# (the `<PROJECT-KEY>` token), and to STOP with an actionable message if it can't be resolved,
# rather than defaulting to any literal key.
#
# Matcher reasoning (why this is general, not `ET`-specific):
#   A test that only greps for the literal string "ET" would pass the moment someone hardcodes a
#   DIFFERENT literal key (e.g. `CER`) instead — same defect, different string. So this test
#   matches the *shape* of a hardcoded call site instead: `--project` followed (after whitespace,
#   with an optional wrapping quote) by a BARE uppercase-letters-only token, e.g. `--project ET`
#   or `--project "CER"`. That shape can only ever be a literal project-key value — it can't match
#   either of the two legitimate forms:
#     - the `<PROJECT-KEY>` placeholder token (starts with `<`, not an uppercase letter)
#     - a shell variable derived from project-context (`$PROJECT_KEY`, `"$PROJECT_KEY"`,
#       `"${PROJECT_KEY}"` — all start with `$`, not an uppercase letter)
#   The scan is also restricted to `plugins/sdlc/commands/` and `plugins/sdlc/agents/` — the two
#   directories NA-78's Expected Result requires to be grep-clean of literal project keys. This
#   deliberately excludes `skills/acli/SKILL.md`, whose `CER` occurrences are generic reference
#   examples, not real call sites in this plugin.
#   False-positive check: prose/table rows like
#     | `-p, --project` | Jira project key (e.g. `CER`) |
#   do NOT match, because "--project" there is immediately followed by a backtick/pipe, not
#   whitespace — the regex requires `[[:space:]]+` directly after `--project`, so it only fires on
#   actual invocation syntax (`--project <value>`), never on a documentation mention of the flag.
#
# Case 2 (STOP-instruction) is a text-presence assertion against a prompt document, not executable
# code, and it is scoped to co-location (`STOP`, "project key", and the literal
# `.claude/project/project-context.md` path all inside the SAME markdown paragraph block — an awk
# `RS=""` paragraph split, blank line = boundary) rather than "all three anywhere in the file",
# since two unconnected mentions elsewhere would not actually prove the STOP clause is attached to
# the right instruction. Still — see the "how strong" caveat in the script's own final PASS/FAIL
# message below: presence-and-proximity in a prompt document proves the instruction is WRITTEN and
# well-placed, never that a dispatched agent obeys it at runtime.
#
# Self-runnable, no test harness/framework dependency:
#   bash plugins/sdlc/scripts/__tests__/no-hardcoded-project-key.test.sh
# Exit 0 = PASS (all cases), non-zero = FAIL (any case).
set -uo pipefail

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
plugin_root="$(cd "$here/../../.." && pwd)/sdlc"
commands_dir="$plugin_root/commands"
agents_dir="$plugin_root/agents"
refine_feature="$commands_dir/refine-feature.md"

failures=0

# Case 1: grep-clean guard — no literal Jira project key may appear as the value of `--project`
# anywhere under plugins/sdlc/commands/ or plugins/sdlc/agents/.
hardcoded_hits="$(grep -rnE -- '--project[[:space:]]+"?[A-Z]{2,10}"?' "$commands_dir" "$agents_dir" 2>/dev/null || true)"
if [ -z "$hardcoded_hits" ]; then
  echo "PASS: grep-clean — no hardcoded --project literal under plugins/sdlc/commands/ or plugins/sdlc/agents/"
else
  echo "FAIL: grep-clean — found hardcoded --project literal(s):"
  printf '%s\n' "$hardcoded_hits" | sed 's/^/    /'
  failures=$((failures + 1))
fi

# Case 2: unresolvable-key STOP — refine-feature.md must instruct a STOP with an actionable
# message when the project key cannot be resolved from project-context, rather than defaulting to
# any literal key. Required co-located in the SAME paragraph block (awk RS="" paragraph split):
# "stop" + "project key" (case-insensitive) + the literal `.claude/project/project-context.md`
# path — proximity, not just presence-anywhere-in-file, so a stray STOP elsewhere in the doc can't
# satisfy this. This is still a text-presence/proximity assertion against a prompt document
# (refine-feature.md has no executable branch to actually exercise), so it can only prove the
# instruction is WRITTEN and well-placed, not that a dispatched agent will faithfully follow it at
# runtime — see the Summary note on how strong this assertion is judged to be.
stop_para_hit="$(awk -v RS="" 'tolower($0) ~ /stop/ && tolower($0) ~ /project key/ && $0 ~ /project-context\.md/ {print "MATCH"; found=1} END{if(!found) exit 1}' "$refine_feature" 2>/dev/null)"
if [ "$stop_para_hit" = "MATCH" ]; then
  echo "PASS: STOP instruction — refine-feature.md has a STOP co-located with the project-key resolution in one paragraph"
else
  echo "FAIL: STOP instruction — refine-feature.md has no STOP co-located with a project-key/project-context.md mention"
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
  echo "PASS: all no-hardcoded-project-key regression cases passed"
  exit 0
else
  echo "FAIL: $failures no-hardcoded-project-key regression case(s) failed"
  exit 1
fi
