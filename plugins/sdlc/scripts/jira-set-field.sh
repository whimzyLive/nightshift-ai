#!/usr/bin/env bash
# jira-set-field.sh — set a Jira issue field by DISPLAY NAME via the REST API.
#
# Why this exists: `acli jira workitem edit` has NO flag for setting custom-field
# VALUES (verified through acli 1.3.22 — `--custom-field` does not exist, and the
# `--from-json` schema exposes no custom fields either). Custom-field stamps
# (story points, workflow-mode fields) must therefore go through the REST API.
#
# Usage:
#   jira-set-field.sh <ISSUE-KEY> <FIELD-DISPLAY-NAMES> <VALUE> [value-type] [--if-empty]
#
#   FIELD-DISPLAY-NAMES: one display name, or a comma-separated preference list —
#     the first name that exists on the site is used. E.g. story points differ by
#     project type, so pass "Story point estimate,Story Points" to probe both.
#
#   value-type: number | string | option   (default: string)
#     number → {"<field>": <VALUE>}          (e.g. story points)
#     option → {"<field>": {"value": "..."}} (single-select fields; falls back
#                                             to plain string on HTTP 400)
#     string → {"<field>": "<VALUE>"}
#
#   --if-empty: only write when the field is currently null/absent on the
#     issue. If a value already exists, print SKIP and exit 0. Use for stamps
#     that must never overwrite a value a human (or a prior run) already set —
#     e.g. story points on refine.
#
# Auth — same headless env contract as the acli skill:
#   ATLASSIAN_SITE, ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN
#
# Exit codes (deterministic — REST/transport failures never leak curl's raw code):
#   0 field set (or SKIP under --if-empty)   2 credentials absent (caller: best-effort skip)
#   3 no listed field name exists            1 REST/transport error
set -euo pipefail

KEY="${1:?usage: jira-set-field.sh <ISSUE-KEY> <FIELD-DISPLAY-NAMES> <VALUE> [number|string|option] [--if-empty]}"
FIELD_NAMES="${2:?field display name(s) required}"
VALUE="${3:?value required}"
VTYPE="${4:-string}"
IF_EMPTY=false
[ "${5:-}" = "--if-empty" ] && IF_EMPTY=true
[ "$VTYPE" = "--if-empty" ] && { VTYPE="string"; IF_EMPTY=true; }

if [ -z "${ATLASSIAN_SITE:-}" ] || [ -z "${ATLASSIAN_EMAIL:-}" ] || [ -z "${ATLASSIAN_API_TOKEN:-}" ]; then
  echo "WARN: ATLASSIAN_SITE/ATLASSIAN_EMAIL/ATLASSIAN_API_TOKEN not set — cannot stamp \"$FIELD_NAMES\" on $KEY via REST" >&2
  exit 2
fi

# Honour an explicit scheme (lets tests point at a local mock); default https
case "$ATLASSIAN_SITE" in
  http://*|https://*) BASE="$ATLASSIAN_SITE" ;;
  *)                  BASE="https://${ATLASSIAN_SITE}" ;;
esac
AUTH="${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}"

# Fetch the field list in a guarded step so a transport/auth failure exits 1
# (REST error) instead of leaking curl's raw exit code or being mistaken for
# a missing field (exit 3).
FIELDS_JSON=$(curl -sf -u "$AUTH" "${BASE}/rest/api/3/field") \
  || { echo "ERROR: could not list fields on ${BASE} (network/auth)" >&2; exit 1; }

FIELD_ID="" FIELD_NAME=""
IFS=',' read -ra NAME_LIST <<< "$FIELD_NAMES"
for name in "${NAME_LIST[@]}"; do
  name="${name#"${name%%[![:space:]]*}"}"   # trim leading/trailing whitespace so
  name="${name%"${name##*[![:space:]]}"}"   # "A, B" probes "B", not " B"
  FIELD_ID=$(printf '%s' "$FIELDS_JSON" \
    | jq -r --arg n "$name" '[.[] | select(.name == $n)][0].id // empty') \
    || { echo "ERROR: unparseable field-list JSON from ${BASE}" >&2; exit 1; }
  if [ -n "$FIELD_ID" ]; then FIELD_NAME="$name"; break; fi
done
if [ -z "$FIELD_ID" ]; then
  echo "WARN: none of the field name(s) \"$FIELD_NAMES\" found on ${BASE}" >&2
  exit 3
fi

if [ "$IF_EMPTY" = true ]; then
  # A failed read must abort (exit 1), NEVER pass as "empty" — otherwise a
  # transient error would silently bypass the no-overwrite guard.
  ISSUE_JSON=$(curl -sf -u "$AUTH" "${BASE}/rest/api/3/issue/${KEY}?fields=${FIELD_ID}") \
    || { echo "ERROR: could not read ${KEY} to check existing \"$FIELD_NAME\" value" >&2; exit 1; }
  CURRENT=$(printf '%s' "$ISSUE_JSON" | jq -r --arg f "$FIELD_ID" '.fields[$f] // empty') \
    || { echo "ERROR: unparseable issue JSON for ${KEY}" >&2; exit 1; }
  if [ -n "$CURRENT" ]; then
    echo "SKIP: ${KEY} ${FIELD_NAME} (${FIELD_ID}) already set — not overwriting"
    exit 0
  fi
fi

build_body() {
  case "$1" in
    number) jq -n --arg f "$FIELD_ID" --argjson v "$VALUE" '{fields: {($f): $v}}' ;;
    option) jq -n --arg f "$FIELD_ID" --arg v "$VALUE" '{fields: {($f): {value: $v}}}' ;;
    *)      jq -n --arg f "$FIELD_ID" --arg v "$VALUE" '{fields: {($f): $v}}' ;;
  esac
}

put_field() {
  curl -s -o /dev/null -w '%{http_code}' -X PUT \
    -u "$AUTH" -H "Content-Type: application/json" \
    -d "$(build_body "$1")" "${BASE}/rest/api/3/issue/${KEY}"
}

# Guard the assignments: a curl transport failure prints 000 / exits non-zero —
# normalise to the documented exit 1 instead of dying with curl's raw code.
HTTP_CODE=$(put_field "$VTYPE") || HTTP_CODE="000"
if [ "$HTTP_CODE" = "400" ] && [ "$VTYPE" = "option" ]; then
  # Field is a plain text/number field, not a select — retry as string
  HTTP_CODE=$(put_field string) || HTTP_CODE="000"
fi
if [ "$HTTP_CODE" != "204" ]; then
  echo "ERROR: setting \"$FIELD_NAME\" ($FIELD_ID) on $KEY failed — HTTP $HTTP_CODE" >&2
  exit 1
fi
echo "OK: ${KEY} ${FIELD_NAME} (${FIELD_ID}) = ${VALUE}"
