#!/usr/bin/env bash
set -uo pipefail
# assert-workspace-clean.sh — `snapshot` / `assert` pair for the primary-checkout isolation
# guarantee, extracted from the identical block duplicated verbatim between
# refs/principal-engineer-playbook.md Step 5 and refs/qa-engineer-playbook.md Step 3 (NA-86 A9).
#
# The CONSEQUENCE of a violation stays caller-specific and lives in the two playbooks, not here:
# the Principal Engineer fails the phase and STOPs; the QA Engineer returns `blocked` and never
# self-repairs. This script only reports the fact — WORKSPACE_INTEGRITY / WORKSPACE_VIOLATION.
#
# Invocation:
#   bash ${CLAUDE_PLUGIN_ROOT}/scripts/assert-workspace-clean.sh snapshot <primary-root>
#   bash ${CLAUDE_PLUGIN_ROOT}/scripts/assert-workspace-clean.sh assert <primary-root> <state-file>
#
# A row that can verify the workspace exits 0 — the decision lives in stdout, never the exit
# code. A row that CANNOT verify (a failed git probe, or, on `assert`, a missing/unreadable/
# malformed state file) is a hard error: it exits non-zero, prints the reason to stderr, and
# emits no WorkspaceAssertResult/WorkspaceSnapshotResult line at all — never a fabricated verdict.
#
# `snapshot` stdout (WorkspaceSnapshotResult) — three KEY=value lines:
#   PRIMARY_HEAD         40-char oid — `git -C <primary-root> rev-parse HEAD`, as-is
#   PRIMARY_STATE_FILE   absolute path inside the session tmp dir (tmp-dir.sh) — pass verbatim to
#                        the paired `assert` call so the value survives between the two calls
#   PRIMARY_PRE_DIRTY    'true' | 'false' — non-empty `git status --porcelain` at snapshot time,
#                        captured AS-IS. A non-empty status here is a snapshot fact, never itself a
#                        failure — the CALLER emits the one-line pre-existing-dirt warning and
#                        proceeds; it is not a STOP (PE) and not a `blocked` (QA).
#
# `assert` stdout (WorkspaceAssertResult) — two KEY=value lines:
#   WORKSPACE_INTEGRITY   'OK' | 'VIOLATED'
#   WORKSPACE_VIOLATION   'none' | 'head-moved' | 'worktree-changed' | 'both'
#
# assert passes (OK/none) IFF HEAD is identical AND the porcelain status is identical to the
# snapshot — only a CHANGE from the snapshot is a violation; a snapshot taken pre-dirty that stays
# at the SAME dirt is a pass. A missing/unreadable/malformed state file on assert is a hard error
# (see above) — it is NOT a verified violation, since there is nothing to compare against.
#
# Capture-staging exclusion (NA-98 fix-round, retargeted by NA-101, legacy entry removed by
# NA-103): capture_root_rel excludes exactly ONE entry from porcelain — capture-learning.sh's
# resolve_capture_root: SDLC_CAPTURE_ROOT if set, else <memory-root>/captured, where <memory-root>
# comes from memory-root.sh and resolves OUTSIDE every checkout by default, so under that default
# this entry is empty (nothing under the primary to filter). Porcelain lines under a matched entry
# are stripped before both the snapshot is recorded and the assert comparison runs, so a capture
# write via the current staging root can never trip WORKSPACE_INTEGRITY on its own — every other
# primary-checkout mutation still can.
#
# NA-103 deleted the second, always-on `.claude/memories/captured` carve-out (the pre-NA-101
# legacy in-repo path): the tracked corpus migration (NA-102) leaves nothing but a `.gitignore`
# marker under that path in any repo that has completed migration, and this story deletes that
# marker too. A repo that still has real content staged at the legacy path (never migrated, or
# captured before NA-101 shipped) now correctly shows as dirty — that content is stale and belongs
# in the resolved external root (capture-learning.sh's current SDLC_CAPTURE_ROOT/memory-root.sh
# resolution), not silently hidden here.

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."
# shellcheck source=/dev/null
. "$here/memory-root.sh"

# abspath <path> -> an absolute path, without requiring realpath/readlink -f (portability).
# tmp-dir.sh returns a CWD-relative "./.tmp/..." dir, so mktemp's PRIMARY_STATE_FILE would
# otherwise be relative too — and the documented contract (line 19) is that the CALLER may `cd`
# between the `snapshot` and paired `assert` invocations (the PE playbook's Step 4 prompt
# contract mandates exactly that), so a relative path silently resolves to a different file.
abspath() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$(cd "$(dirname "$1")" 2>/dev/null && pwd)" "$(basename "$1")" ;;
  esac
}

# capture_root_rel <primary-root-abs> -> one line: the current capture-staging path RELATIVE to
# <primary-root-abs> to exclude from porcelain (or empty for "nothing to filter"). This is the
# root honouring SDLC_CAPTURE_ROOT, same as capture-learning.sh's resolve_capture_root — empty
# when that root isn't under the primary checkout at all, since it can then never appear in
# `git -C <primary-root> status --porcelain` output anyway.
capture_root_rel() {
  local primary_abs="$1" cap rel
  if [ -n "${SDLC_CAPTURE_ROOT:-}" ]; then
    cap="$SDLC_CAPTURE_ROOT"
  else
    # A resolver failure must never fabricate a verdict: fall through to an empty rel (passthrough).
    cap="$(sdlc_memory_root 2>/dev/null)" && cap="$cap/captured"
  fi
  rel=""
  if [ -n "${cap:-}" ]; then
    case "$cap" in
      "$primary_abs"/*) rel="${cap#"$primary_abs"/}" ;;
      "$primary_abs")   rel="." ;;
    esac
  fi
  printf '%s\n' "$rel"
}

# filter_capture_lines <rel> — reads porcelain status on stdin, drops any line whose path is <rel>
# (capture_root_rel's single entry) or lives under it. An empty <rel> passes everything through
# (not a match against anything). Porcelain v1 lines are always `XY<space>PATH` (3-char fixed
# prefix), regardless of what X/Y are — a rename never applies here since the excluded root is
# entirely `??`/ignored, never staged.
filter_capture_lines() {
  local rel1="$1"
  awk -v rel1="$rel1" '
    function excluded(path, rel) {
      return rel != "" && (path == rel || path == rel "/" || index(path, rel "/") == 1)
    }
    {
      path = substr($0, 4)
      gsub(/^"/, "", path); gsub(/"$/, "", path)
      if (excluded(path, rel1)) next
      print
    }
  '
}

SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
  snapshot)
    PRIMARY_ROOT="${1:-}"
    [ -n "$PRIMARY_ROOT" ] || {
      echo "usage: assert-workspace-clean.sh snapshot <primary-root>" >&2
      exit 1
    }

    dir="$(bash "$here/tmp-dir.sh")"
    raw_state_file="$(mktemp "$dir/workspace-snapshot.XXXXXX")" || {
      echo "assert-workspace-clean.sh: mktemp failed under '$dir' — cannot snapshot" >&2
      exit 1
    }
    state_file="$(abspath "$raw_state_file")"

    # A failed git probe (mis-substituted placeholder, a non-top-level path, a `safe.directory`
    # refusal, ...) must be a hard error, never a silently-empty value — an empty head/status
    # would make `assert` compare two unknowns as equal and report a false OK (fail-open).
    head_oid="$(git -C "$PRIMARY_ROOT" rev-parse HEAD)" || {
      echo "assert-workspace-clean.sh: git rev-parse HEAD failed in '$PRIMARY_ROOT' — cannot snapshot" >&2
      exit 1
    }
    status_out="$(git -C "$PRIMARY_ROOT" status --porcelain)" || {
      echo "assert-workspace-clean.sh: git status --porcelain failed in '$PRIMARY_ROOT' — cannot snapshot" >&2
      exit 1
    }
    cap_rel="$(capture_root_rel "$(abspath "$PRIMARY_ROOT")")"
    status_out="$(printf '%s' "$status_out" | filter_capture_lines "$cap_rel")"

    # Line 1 = HEAD oid; every remaining line = one porcelain status row (empty when clean).
    {
      printf '%s\n' "$head_oid"
      printf '%s' "$status_out"
    } > "$state_file" || {
      echo "assert-workspace-clean.sh: failed writing state file '$state_file' — cannot snapshot" >&2
      exit 1
    }

    PRIMARY_PRE_DIRTY=false
    [ -n "$status_out" ] && PRIMARY_PRE_DIRTY=true

    printf 'PRIMARY_HEAD=%s\n' "$head_oid"
    printf 'PRIMARY_STATE_FILE=%s\n' "$state_file"
    printf 'PRIMARY_PRE_DIRTY=%s\n' "$PRIMARY_PRE_DIRTY"
    exit 0
    ;;
  assert)
    PRIMARY_ROOT="${1:-}"
    STATE_FILE="${2:-}"
    [ -n "$PRIMARY_ROOT" ] && [ -n "$STATE_FILE" ] || {
      echo "usage: assert-workspace-clean.sh assert <primary-root> <state-file>" >&2
      exit 1
    }

    [ -r "$STATE_FILE" ] || {
      echo "assert-workspace-clean.sh: state file '$STATE_FILE' is missing or unreadable — cannot verify workspace integrity" >&2
      exit 1
    }

    snap_head="$(sed -n '1p' "$STATE_FILE")"
    snap_status="$(tail -n +2 "$STATE_FILE")"

    printf '%s' "$snap_head" | grep -qE '^[0-9a-f]{40}$|^[0-9a-f]{64}$' || {
      echo "assert-workspace-clean.sh: state file '$STATE_FILE' is malformed (line 1 is not a git oid) — cannot verify workspace integrity" >&2
      exit 1
    }

    cur_head="$(git -C "$PRIMARY_ROOT" rev-parse HEAD)" || {
      echo "assert-workspace-clean.sh: git rev-parse HEAD failed in '$PRIMARY_ROOT' — cannot assert" >&2
      exit 1
    }
    cur_status="$(git -C "$PRIMARY_ROOT" status --porcelain)" || {
      echo "assert-workspace-clean.sh: git status --porcelain failed in '$PRIMARY_ROOT' — cannot assert" >&2
      exit 1
    }
    cap_rel="$(capture_root_rel "$(abspath "$PRIMARY_ROOT")")"
    cur_status="$(printf '%s' "$cur_status" | filter_capture_lines "$cap_rel")"

    head_changed=false
    [ "$cur_head" = "$snap_head" ] || head_changed=true
    tree_changed=false
    [ "$cur_status" = "$snap_status" ] || tree_changed=true

    if [ "$head_changed" = false ] && [ "$tree_changed" = false ]; then
      WORKSPACE_INTEGRITY=OK
      WORKSPACE_VIOLATION=none
    elif [ "$head_changed" = true ] && [ "$tree_changed" = true ]; then
      WORKSPACE_INTEGRITY=VIOLATED
      WORKSPACE_VIOLATION=both
    elif [ "$head_changed" = true ]; then
      WORKSPACE_INTEGRITY=VIOLATED
      WORKSPACE_VIOLATION=head-moved
    else
      WORKSPACE_INTEGRITY=VIOLATED
      WORKSPACE_VIOLATION=worktree-changed
    fi

    printf 'WORKSPACE_INTEGRITY=%s\n' "$WORKSPACE_INTEGRITY"
    printf 'WORKSPACE_VIOLATION=%s\n' "$WORKSPACE_VIOLATION"
    exit 0
    ;;
  *)
    echo "usage: assert-workspace-clean.sh snapshot <primary-root> | assert <primary-root> <state-file>" >&2
    exit 1
    ;;
esac
