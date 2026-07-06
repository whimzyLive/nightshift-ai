#!/usr/bin/env bash
# jira-set-field.sh — set a Jira issue field by DISPLAY NAME via the REST API.
#
# Why this exists: `acli jira workitem edit` has NO flag for setting custom-field
# VALUES (verified through acli 1.3.22 — `--custom-field` does not exist, and the
# `--from-json` schema exposes no custom fields either). Custom-field stamps
# (story points, workflow-mode fields) must therefore go through the REST API.
#
# Usage:
#   jira-set-field.sh <ISSUE-KEY> <FIELD-DISPLAY-NAME> <VALUE> [value-type] [--if-empty]
#
#   value-type: number | string | option   (default: string)
#     number → {"<field>": <VALUE>}          (e.g. story points)
#     option → {"<field>": {"value": "..."}} (single-select fields; falls back
#                                             to plain string on HTTP 400)
#     string → {"<field>": "<VALUE>"}
#
#   --if-empty: only write when the field is currently null/absent on the
#     issue. If a value already exists, print SKIP and exit 0 (deliberately
#     success, so `helper A || helper B` probe chains don't fall through to
#     the next field name). Use for stamps that must never overwrite a value
#     a human (or a prior run) already set — e.g. story points on refine.
#
# Auth — same headless env contract as the acli skill:
#   ATLASSIAN_SITE, ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN
#
# Exit codes:
#   0 field set (or SKIP under --if-empty)   2 credentials absent (caller: best-effort skip)
#   3 field name not found                   1 REST error
set -euo pipefail

KEY="${1:?usage: jira-set-field.sh <ISSUE-KEY> <FIELD-DISPLAY-NAME> <VALUE> [number|string|option] [--if-empty]}"
FIELD_NAME="${2:?field display name required}"
VALUE="${3:?value required}"
VTYPE="${4:-string}"
IF_EMPTY=false
[ "${5:-}" = "--if-empty" ] && IF_EMPTY=true
[ "$VTYPE" = "--if-empty" ] && { VTYPE="string"; IF_EMPTY=true; }

if [ -z "${ATLASSIAN_SITE:-}" ] || [ -z "${ATLASSIAN_EMAIL:-}" ] || [ -z "${ATLASSIAN_API_TOKEN:-}" ]; then
  echo "WARN: ATLASSIAN_SITE/ATLASSIAN_EMAIL/ATLASSIAN_API_TOKEN not set — cannot stamp \"$FIELD_NAME\" on $KEY via REST" >&2
  exit 2
fi

BASE="https://${ATLASSIAN_SITE#https://}"
AUTH="${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}"

FIELD_ID=$(curl -sf -u "$AUTH" "${BASE}/rest/api/3/field" \
  | jq -r --arg n "$FIELD_NAME" '[.[] | select(.name == $n)][0].id // empty')
if [ -z "$FIELD_ID" ]; then
  echo "WARN: field \"$FIELD_NAME\" not found on ${BASE}" >&2
  exit 3
fi

if [ "$IF_EMPTY" = true ]; then
  CURRENT=$(curl -sf -u "$AUTH" "${BASE}/rest/api/3/issue/${KEY}?fields=${FIELD_ID}" \
    | jq -r --arg f "$FIELD_ID" '.fields[$f] // empty')
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

HTTP_CODE=$(put_field "$VTYPE")
if [ "$HTTP_CODE" = "400" ] && [ "$VTYPE" = "option" ]; then
  # Field is a plain text/number field, not a select — retry as string
  HTTP_CODE=$(put_field string)
fi
if [ "$HTTP_CODE" != "204" ]; then
  echo "ERROR: setting \"$FIELD_NAME\" ($FIELD_ID) on $KEY failed — HTTP $HTTP_CODE" >&2
  exit 1
fi
echo "OK: ${KEY} ${FIELD_NAME} (${FIELD_ID}) = ${VALUE}"
