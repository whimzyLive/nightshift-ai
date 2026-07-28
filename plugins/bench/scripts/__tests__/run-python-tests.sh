#!/usr/bin/env bash
# Runs every bench Python unittest module. Self-runnable, no framework:
#   bash plugins/bench/scripts/__tests__/run-python-tests.sh
# Exit 0 = all pass, non-zero = failure.
set -euo pipefail

here="${0%/*}"
[ "$here" = "$0" ] && here="."

python3 -m unittest discover -s "$here" -p 'test_*.py' -v
