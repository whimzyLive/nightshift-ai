#!/usr/bin/env bash
# Run ONE benchmark cell end to end: preflight -> provision -> execute ->
# tests -> measure -> grade -> report.
#
# Staged deliberately, because the stages differ in what they cost and in what
# they leave behind:
#
#   free      preflight, resolve            reads Jira, spends nothing
#   creates   provision                     a Jira issue, a branch, a worktree
#   spends    execute                       ONE measured session (the benchmark)
#   spends    grade                         THREE more sessions, one per grader
#   free      measure, report               reads files already on disk
#
# Default stops after the free stages and prints what the rest would do. `--go`
# runs through execute. Grading is gated separately by `--grade`, because three
# grader sessions have been invoked by accident before now (~92k tokens) and
# they are not needed to answer "what did this cost and what did it ship".
#
# Usage:
#   bash run-cell.sh --ticket NA-82 --adapter sdlc-0.45.4 --run-id r1 [--go] [--grade]
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
S="$REPO/plugins/bench/scripts"
A="$REPO/plugins/bench/approaches"

TICKET=""; ADAPTER=""; RUN_ID="r1"; GO=0; GRADE=0; WATCH=0; TWIN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) TICKET="$2"; shift 2 ;;
    --adapter) ADAPTER="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --go) GO=1; shift ;;
    --grade) GRADE=1; shift ;;
    --watch) WATCH=1; shift ;;
    --twin-ticket) TWIN="$2"; shift 2 ;;
    *) echo "unknown argument: $1"; exit 1 ;;
  esac
done
[ -n "$TICKET" ] && [ -n "$ADAPTER" ] || {
  echo "usage: run-cell.sh --ticket <KEY> --adapter <name> --run-id <id> [--go] [--grade] [--watch] [--twin-ticket <KEY>]"
  exit 1
}

YAML="$A/$ADAPTER.yaml"
[ -f "$YAML" ] || { echo "no such adapter: $YAML"; exit 1; }

# The cell's identity comes from the adapter, not from the flags -- provision
# and execute both refuse a cell whose identity disagrees with its adapter, and
# deriving it here means one source of truth instead of three.
read -r APPROACH VERSION CELL <<EOF
$(python3 -c "
import sys; sys.path.insert(0, '$S')
from pathlib import Path
from benchlib import adapters
a = adapters.load_adapter(Path('$YAML'))
print(a.id, a.version.version if a.version else '-', a.cell_id)
")
EOF
[ -n "${CELL:-}" ] || { echo "could not read the adapter's identity"; exit 1; }

BASE="docs/benchmarks/$TICKET"
DIR="$BASE/$CELL/$RUN_ID"
mkdir -p "$REPO/$DIR"

echo "=============================================================="
echo " cell    : $CELL   run: $RUN_ID   ticket: $TICKET"
echo " adapter : $YAML"
echo " output  : $DIR"
echo "=============================================================="

# ---- free: resolve -----------------------------------------------------------
echo
echo "[1/7] resolve — read the ticket (free)"
python3 "$S/resolve.py" --key "$TICKET" --repo "$REPO" \
  --out "$REPO/$BASE/story.json" || {
  echo "STOP: could not resolve $TICKET. If this says the issue does not exist,"
  echo "      check 'acli jira auth status' points at the configured Jira site"
  echo "      before concluding the ticket is missing."
  exit 1
}

POINTS="$(python3 -c "
import json; print(json.load(open('$REPO/$BASE/story.json'))['points'])")"
echo "      story points: $POINTS"
if [ "$POINTS" = "None" ]; then
  echo "      WARNING: points are unset in Jira. /sdlc:auto triages on points"
  echo "      against the configured lightweight threshold, so an unset value"
  echo "      may route this cell down the SHORT path while the report labels"
  echo "      it as the full lifecycle. Set them before trusting the row."
fi

# ---- free: preflight ---------------------------------------------------------
echo
echo "[2/7] preflight — forecast and blast radius (free)"
python3 "$S/preflight.py" --ticket "$TICKET" --repo "$REPO" --repeats 1 \
  --adapter "$YAML"
PF=$?
[ $PF -eq 0 ] || {
  echo "STOP: preflight refused (exit $PF). Nothing has been spent."
  exit $PF
}

if [ $GO -eq 0 ]; then
  cat <<EOF

--------------------------------------------------------------------------
Stopping here. Nothing has been created and nothing spent.

To proceed, re-run with --go. That will:
  * create a scratch Jira issue cloned from $TICKET, plus a branch and worktree
  * run ONE measured \`claude\` session — this is the benchmark, and the spend
  * open a DRAFT pull request (the guard denies a non-draft one)

Add --watch to stream the session live instead of waiting in silence.
Add --grade to also run three grader sessions afterwards. Leave it off if you
only want cost and shipped output; grading is what scores AC coverage.

Before the first SDLC cell: bash $S/verify-runtime.sh
It confirms the push guard actually loads. If it does not, this cell can push
to refs the harness believes are blocked.

Clean up afterwards with:
  python3 $S/cleanup.py --ticket $TICKET --repo $REPO
--------------------------------------------------------------------------
EOF
  exit 0
fi

# ---- creates: provision ------------------------------------------------------
echo
echo "[3/7] provision — worktree, guard, scratch issue (CREATES THINGS)"
VERSION_FLAG=()
[ "$VERSION" != "-" ] && VERSION_FLAG=(--version "$VERSION")
python3 "$S/provision.py" \
  --story "$REPO/$BASE/story.json" \
  --approach "$APPROACH" "${VERSION_FLAG[@]}" \
  --run-id "$RUN_ID" --repo "$REPO" --adapter "$YAML" \
  ${TWIN:+--twin-ticket "$TWIN"} \
  --out "$REPO/$DIR/cell.json" || { echo "STOP: provisioning failed."; exit 1; }

WORKTREE="$(python3 -c "
import json; print(json.load(open('$REPO/$DIR/cell.json'))['worktree'])")"
ARTIFACTS="$(python3 -c "
import json; print(json.load(open('$REPO/$DIR/cell.json'))['artifacts'])")"
SCRATCH="$(python3 -c "
import json; print(json.load(open('$REPO/$DIR/cell.json')).get('twin_ticket') or '-')")"

# A cell whose adapter wants a scratch issue but has none would run the real
# lifecycle against the SOURCE ticket. Stop rather than write to it.
WANTS_SCRATCH="$(python3 -c "
import sys; sys.path.insert(0, '$S')
from pathlib import Path
from benchlib import adapters
print(int(adapters.load_adapter(Path('$YAML')).dedicated_ticket))
")"
if [ "$WANTS_SCRATCH" = "1" ] && [ "$SCRATCH" = "-" ]; then
  echo "STOP: this adapter needs a dedicated ticket but none is recorded."
  echo "      Continuing would run the lifecycle against $TICKET itself."
  exit 1
fi

# ---- spends: execute ---------------------------------------------------------
echo
echo "[4/7] execute — THE MEASURED SESSION (this is the spend)"

# --watch streams the session's transcript while it runs. Without it this step
# prints nothing at all for the whole cell -- `--output-format json` emits one
# blob at the end -- and 20 minutes of silence has already been read as a hung
# run when the run was fine.
#
# A background reader, not a change to how the session is invoked: the watcher
# only reads a transcript file, so it cannot affect the measurement.
WATCH_PID=""
if [ $WATCH -eq 1 ]; then
  bash "$S/watch-cell.sh" "$(basename "$WORKTREE")" &
  WATCH_PID=$!
  # Stop the watcher on any exit path, including Ctrl-C, so it never outlives
  # the run it is describing.
  trap 'kill $WATCH_PID 2>/dev/null' EXIT INT TERM
fi

python3 "$S/execute.py" \
  --cell "$REPO/$DIR/cell.json" \
  --story "$REPO/$BASE/story.json" \
  --adapter "$YAML" \
  --out "$REPO/$DIR/result.json"
EXEC=$?
if [ -n "$WATCH_PID" ]; then
  kill "$WATCH_PID" 2>/dev/null
  WATCH_PID=""
  echo
fi
[ $EXEC -eq 0 ] || echo "      execute exited $EXEC — continuing to measure so the"
[ $EXEC -eq 0 ] || echo "      partial record is captured rather than discarded."

# ---- free-ish: test evidence -------------------------------------------------
echo
echo "[5/7] tests — capture evidence for graders"
TEST_COMMAND="$(python3 -c "
import sys; sys.path.insert(0, '$S')
from pathlib import Path
from benchlib import config
cfg = config.load_config(Path('$REPO'), {})
print(config.require_command(cfg.test_command, 'test'))
")" || { echo "STOP: no usable test command configured."; exit 1; }
echo "      $TEST_COMMAND"
( cd "$WORKTREE" && eval "$TEST_COMMAND" ) > "$ARTIFACTS/tests.txt" 2>&1 || true
echo "      -> $ARTIFACTS/tests.txt ($(wc -l < "$ARTIFACTS/tests.txt") lines)"

# ---- free: measure -----------------------------------------------------------
echo
echo "[6/7] measure — reconstruct cost from the transcript (free)"
python3 "$S/measure.py" \
  --cell "$REPO/$DIR/cell.json" \
  --result "$REPO/$DIR/result.json" \
  --adapter "$YAML" \
  --out "$REPO/$DIR/run.json"
MEASURE=$?

python3 - "$REPO/$DIR/run.json" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1]))
except Exception as exc:
    print("      could not read run.json:", exc); raise SystemExit(0)
def g(*path, default=None):
    cur = r
    for k in path:
        cur = (cur or {}).get(k) if isinstance(cur, dict) else None
    return cur if cur is not None else default
print("      cost (API-eq) :", g("total", "reported_cost_usd"))
print("      billing mode  :", g("billing_mode", "mode"))
print("      version loaded:", g("plugin_version", "resolved") or "unverified")
flags = []
if g("termination", "clean") is False: flags.append("CUT OFF mid-run — figures describe a partial run; do not grade")
if g("work_done", "empty_diff"): flags.append("EMPTY DIFF — the session committed nothing; do not grade")
if g("plugin_version", "ok") is False: flags.append("WRONG VER — pin did not take; row belongs to another version")
if g("phase_attribution", "available") is False: flags.append("no phase split — the per-phase columns are artefacts")
if g("reconciliation", "ok") is False: flags.append("RECONCILIATION FAILED — excluded from aggregates")
for f in flags: print("      FLAG:", f)
PY

# ---- spends: grade -----------------------------------------------------------
if [ $GRADE -eq 1 ]; then
  echo
  echo "[7/7] grade — THREE grader sessions (more spend)"
  python3 "$S/grade.py" \
    --cell "$REPO/$DIR/cell.json" \
    --story "$REPO/$BASE/story.json" \
    --out "$REPO/$DIR/grades.json" || echo "      grading failed; the cost row survives."
else
  echo
  echo "[7/7] grade — SKIPPED (pass --grade to score AC coverage; 3 sessions)"
fi

# ---- free: report ------------------------------------------------------------
echo
echo "report —"
python3 "$S/report.py" --ticket "$TICKET" --benchmarks "$REPO/$BASE/.." \
  --out "$REPO/$BASE/report.md" >/dev/null 2>&1 \
  || python3 "$S/report.py" --ticket "$TICKET" --out "$REPO/$BASE/report.md"
echo "      -> $BASE/report.md"

cat <<EOF

--------------------------------------------------------------------------
twin Jira issue    : $SCRATCH
worktree           : $WORKTREE
report             : $BASE/report.md

Look at the shipped output on the draft PR for $SCRATCH. Then:
  python3 $S/cleanup.py --ticket $TICKET --repo $REPO            # dry run
  python3 $S/cleanup.py --ticket $TICKET --repo $REPO --confirm  # delete
--------------------------------------------------------------------------
EOF
