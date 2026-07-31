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
# Every row exits 0 — the decision lives in stdout, never the exit code.
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
# at the SAME dirt is a pass. A missing state file on assert is VIOLATED/both — fail closed.

here="${BASH_SOURCE[0]%/*}"; [ "$here" = "${BASH_SOURCE[0]}" ] && here="."

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
    state_file="$(mktemp "$dir/workspace-snapshot.XXXXXX")"

    head_oid="$(git -C "$PRIMARY_ROOT" rev-parse HEAD)"
    status_out="$(git -C "$PRIMARY_ROOT" status --porcelain)"

    # Line 1 = HEAD oid; every remaining line = one porcelain status row (empty when clean).
    {
      printf '%s\n' "$head_oid"
      printf '%s' "$status_out"
    } > "$state_file"

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

    if [ ! -f "$STATE_FILE" ]; then
      # Fail closed: no snapshot to compare against is itself a violation, never a silent pass.
      printf 'WORKSPACE_INTEGRITY=%s\n' "VIOLATED"
      printf 'WORKSPACE_VIOLATION=%s\n' "both"
      exit 0
    fi

    snap_head="$(sed -n '1p' "$STATE_FILE")"
    snap_status="$(tail -n +2 "$STATE_FILE")"

    cur_head="$(git -C "$PRIMARY_ROOT" rev-parse HEAD)"
    cur_status="$(git -C "$PRIMARY_ROOT" status --porcelain)"

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
