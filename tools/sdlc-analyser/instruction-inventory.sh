#!/usr/bin/env bash
# instruction-inventory.sh — see tools/sdlc-analyser/README.md for the counting rules.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"
scan_root="plugins/sdlc"

mode="inventory"
base_ref=""
json_out=0

while [ $# -gt 0 ]; do
  case "$1" in
    --padding) mode="padding"; shift ;;
    --json) json_out=1; shift ;;
    --base)
      [ $# -ge 2 ] || { echo "instruction-inventory: --base requires a git ref" >&2; exit 1; }
      base_ref="$2"
      shift 2
      ;;
    --root)
      [ $# -ge 2 ] || { echo "instruction-inventory: --root requires a directory" >&2; exit 1; }
      scan_root="${2%/}"
      shift 2
      ;;
    *)
      echo "instruction-inventory: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$repo_root/$scan_root" ]; then
  echo "instruction-inventory: root directory does not exist: $repo_root/$scan_root" >&2
  exit 1
fi

if [ -n "$base_ref" ]; then
  if ! git -C "$repo_root" rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
    echo "instruction-inventory: unknown git ref: $base_ref" >&2
    exit 1
  fi
fi

# A root with none of the recognised top-level category directories reports every row as
# "artifact" (e.g. --root docs/superpowers); a root with at least one keeps today's category_of
# behaviour unchanged ("other" for unrecognised sub-paths).
root_has_categories=0
for d in commands agents refs skills scripts; do
  if [ -d "$repo_root/$scan_root/$d" ]; then root_has_categories=1; break; fi
done

category_of() { # $1=repo-relative path under $scan_root
  if [ "$root_has_categories" -eq 0 ]; then
    echo "artifact"
    return
  fi
  local rel="${1#"$scan_root"/}"
  case "$rel" in
    commands/*) echo "command" ;;
    agents/*)   echo "agent" ;;
    refs/*)     echo "ref" ;;
    skills/*)   echo "skill" ;;
    scripts/*)  echo "script" ;;
    *)          echo "other" ;;
  esac
}

is_vendored() { # $1=repo-relative path under plugins/sdlc
  case "$1" in
    "$scan_root"/skills/find-skills/*|"$scan_root"/skills/skill-creator/*) return 0 ;;
    *) return 1 ;;
  esac
}

est_tokens() { # $1=bytes
  awk -v b="$1" 'BEGIN { printf "%d", b / 3.7 }'
}

padding_counts() { # reads content on stdin, prints "<contentRows> <delimiterRows>"
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    BEGIN { fence = 0; content = 0; delim = 0 }
    {
      t = trim($0)
      if (t ~ /^```/) { fence = !fence; next }
      if (fence) next
      if (t !~ /^\|.*\|$/) next
      inner = substr(t, 2, length(t) - 2)
      n = split(inner, cells, "|")
      isdelim = 1
      for (i = 1; i <= n; i++) {
        c = trim(cells[i])
        if (c !~ /^:?-+:?$/) isdelim = 0
      }
      if (isdelim) {
        padded = 0
        for (i = 1; i <= n; i++) {
          c = trim(cells[i])
          gsub(/:/, "", c)
          if (length(c) > 3) padded = 1
        }
        if (padded) delim++
      } else {
        if (t ~ /\|[ \t][ \t]+[^ \t|]/ || t ~ /[^ \t|][ \t][ \t]+\|/) content++
      }
    }
    END { printf "%d %d\n", content, delim }
  '
}

rows_tsv="$(mktemp)"
trap 'rm -f "$rows_tsv"' EXIT

while IFS= read -r abs_path; do
  rel_path="${abs_path#"$repo_root"/}"
  bytes="$(wc -c < "$abs_path" | tr -d ' ')"
  tokens="$(est_tokens "$bytes")"
  category="$(category_of "$rel_path")"
  if is_vendored "$rel_path"; then vendored="true"; else vendored="false"; fi
  content_rows=0
  delim_rows=0
  if [ "$mode" = "padding" ]; then
    read -r content_rows delim_rows < <(padding_counts < "$abs_path")
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$rel_path" "$bytes" "$tokens" "$category" "$vendored" "$content_rows" "$delim_rows" \
    >> "$rows_tsv"
done < <(find "$repo_root/$scan_root" -type f -name '*.md' | sort)

total_tokens=0
total_content_rows=0
total_delim_rows=0
while IFS=$'\t' read -r _ _ tokens _ vendored content_rows delim_rows; do
  [ "$vendored" = "true" ] && continue
  total_tokens=$(( total_tokens + tokens ))
  total_content_rows=$(( total_content_rows + content_rows ))
  total_delim_rows=$(( total_delim_rows + delim_rows ))
done < "$rows_tsv"

total_tokens_at_base=0
total_content_rows_at_base=0
if [ -n "$base_ref" ]; then
  while IFS= read -r rel_path; do
    case "$rel_path" in *.md) ;; *) continue ;; esac
    bytes="$(git -C "$repo_root" show "${base_ref}:${rel_path}" 2>/dev/null | wc -c | tr -d ' ')"
    tokens="$(est_tokens "$bytes")"
    if is_vendored "$rel_path"; then continue; fi
    total_tokens_at_base=$(( total_tokens_at_base + tokens ))
    if [ "$mode" = "padding" ]; then
      read -r content_rows _ < <(git -C "$repo_root" show "${base_ref}:${rel_path}" 2>/dev/null | padding_counts)
      total_content_rows_at_base=$(( total_content_rows_at_base + content_rows ))
    fi
  done < <(git -C "$repo_root" ls-tree -r --name-only "$base_ref" -- "$scan_root")
fi

delta_tokens=$(( total_tokens - total_tokens_at_base ))
delta_content_rows=$(( total_content_rows - total_content_rows_at_base ))

if [ "$json_out" = "1" ]; then
  json_script="$(mktemp)"
  trap 'rm -f "$rows_tsv" "$json_script"' EXIT
  cat > "$json_script" <<'PY'
import json
import sys

(rows_path, mode, base_ref, total_tokens, total_tokens_at_base, delta_tokens,
 total_content_rows, total_delim_rows, total_content_rows_at_base, delta_content_rows) = sys.argv[1:11]

rows = []
with open(rows_path, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        path, bytes_, est_tokens, category, vendored, content_rows, delim_rows = line.split("\t")
        rows.append({
            "path": path,
            "bytes": int(bytes_),
            "estTokens": int(est_tokens),
            "category": category,
            "vendored": vendored == "true",
            "paddedContentRows": int(content_rows),
            "paddedDelimiterRows": int(delim_rows),
        })

report = {
    "mode": mode,
    "baseRef": base_ref,
    "rows": rows,
    "totalEstTokens": int(total_tokens),
    "totalEstTokensAtBase": int(total_tokens_at_base),
    "deltaEstTokens": int(delta_tokens),
    "totalPaddedContentRows": int(total_content_rows),
    "totalPaddedDelimiterRows": int(total_delim_rows),
    "totalPaddedContentRowsAtBase": int(total_content_rows_at_base),
    "deltaPaddedContentRows": int(delta_content_rows),
}
print(json.dumps(report, indent=2))
PY
  python3 "$json_script" "$rows_tsv" "$mode" "$base_ref" "$total_tokens" "$total_tokens_at_base" \
    "$delta_tokens" "$total_content_rows" "$total_delim_rows" "$total_content_rows_at_base" \
    "$delta_content_rows"
else
  printf '%-70s %10s %10s %-8s %-8s %8s %8s\n' \
    "path" "bytes" "estTokens" "category" "vendored" "content" "delim"
  while IFS=$'\t' read -r path bytes tokens category vendored content_rows delim_rows; do
    printf '%-70s %10s %10s %-8s %-8s %8s %8s\n' \
      "$path" "$bytes" "$tokens" "$category" "$vendored" "$content_rows" "$delim_rows"
  done < "$rows_tsv"
  echo
  echo "mode:                        $mode"
  echo "baseRef:                     ${base_ref:-<none>}"
  echo "totalEstTokens:               $total_tokens"
  echo "totalEstTokensAtBase:         $total_tokens_at_base"
  echo "deltaEstTokens:               $delta_tokens"
  echo "totalPaddedContentRows:       $total_content_rows"
  echo "totalPaddedDelimiterRows:     $total_delim_rows"
  echo "totalPaddedContentRowsAtBase: $total_content_rows_at_base"
  echo "deltaPaddedContentRows:       $delta_content_rows"
fi
