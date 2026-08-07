#!/usr/bin/env bash
# memory-root.sh — NA-101. The single resolver for this repository's memory root.
#
# usage (executed):
#   memory-root.sh --print-root    # absolute root, no trailing slash; creates nothing
#   memory-root.sh --print-key     # <repo-key> only
#   memory-root.sh --ensure        # print the root AND create the layout under it, idempotently
#
# usage (sourced):
#   . "${CLAUDE_PLUGIN_ROOT}/scripts/memory-root.sh"
#   sdlc_memory_root [<start-dir>] / sdlc_repo_key [<start-dir>] / sdlc_primary_worktree [<start-dir>]
#   sdlc_memory_ensure <root>
#
# Sourcing is side-effect free BY CONTRACT: it defines functions only — no mkdir, no writes, no
# exit, and no `set`/`shopt` at file scope. Consumers set their own pipefail/nounset/nullglob and
# must get them back exactly as they were. Every function returns non-zero and prints to stderr on
# failure; none ever calls exit. Bash 3.2 compatible.

# sdlc_mr_slug <string> -> lowercase [a-z0-9-] slug. Order matters: an SSH and an HTTPS remote for
# the same repo must collapse to the same slug.
sdlc_mr_slug() {
  printf '%s' "${1:-}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's|^[a-z0-9+.-]*://||' \
          -e 's|^[^@/]*@||' \
          -e 's|/$||' \
          -e 's|\.git$||' \
          -e 's|[^a-z0-9]|-|g' \
          -e 's|--*|-|g' \
          -e 's|^-||' \
          -e 's|-$||'
}

# sdlc_mr_hash8 <string> -> first 8 lowercase hex chars. No trailing newline is fed to the hasher.
sdlc_mr_hash8() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "${1:-}" | shasum -a 256 | cut -c1-8
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "${1:-}" | sha256sum | cut -c1-8
  elif command -v cksum >/dev/null 2>&1; then
    printf '%08x' "$(printf '%s' "${1:-}" | cksum | awk '{print $1}')" | cut -c1-8
  else
    printf 'memory-root.sh: no shasum, sha256sum or cksum available — cannot derive the repo key\n' >&2
    return 1
  fi
}

# sdlc_primary_worktree [<start-dir>] -> the primary worktree's absolute path (git already
# symlink-resolves it, so a linked worktree yields the identical value).
sdlc_primary_worktree() {
  local start="${1:-$PWD}" porcelain primary
  porcelain="$(git -C "$start" worktree list --porcelain 2>/dev/null)" || {
    printf "memory-root.sh: 'git worktree list --porcelain' failed — cannot resolve the memory root\n" >&2
    return 1
  }
  [ -n "$porcelain" ] || {
    printf "memory-root.sh: 'git worktree list --porcelain' failed — cannot resolve the memory root\n" >&2
    return 1
  }
  if printf '%s\n' "$porcelain" | head -3 | grep -q '^bare$'; then
    printf 'memory-root.sh: main repository is bare — no primary checkout\n' >&2
    return 1
  fi
  primary="$(printf '%s\n' "$porcelain" | sed -n 's/^worktree //p' | head -1)"
  [ -n "$primary" ] || {
    printf "memory-root.sh: no 'worktree ' entry in git worktree list output — cannot resolve the memory root\n" >&2
    return 1
  }
  printf '%s\n' "$primary"
}

# sdlc_repo_key [<start-dir>] -> <repo-key>, always matching ^[a-z0-9][a-z0-9-]*$ and never empty.
sdlc_repo_key() {
  local start="${1:-$PWD}" primary h remote first slug suffix max key
  primary="$(sdlc_primary_worktree "$start")" || return 1
  h="$(sdlc_mr_hash8 "$primary")" || return 1

  remote="$(git -C "$primary" remote get-url origin 2>/dev/null)"
  if [ -z "$remote" ]; then
    first="$(git -C "$primary" remote 2>/dev/null | head -1)"
    [ -n "$first" ] && remote="$(git -C "$primary" remote get-url "$first" 2>/dev/null)"
  fi

  if [ -n "$remote" ]; then
    slug="$(sdlc_mr_slug "$remote")"; suffix=""
  else
    slug="$(sdlc_mr_slug "$(basename "$primary")")"; suffix="-$h"
  fi

  # Truncate the LEADING slug so the trailing -<hash8> always survives.
  max=$((100 - ${#suffix}))
  [ "${#slug}" -gt "$max" ] && slug="$(printf '%s' "$slug" | cut -c1-"$max")"

  # Normalisation is the last transformation; the empty-slug fallback is applied AFTER it.
  slug="$(printf '%s' "$slug" | sed -e 's|--*|-|g' -e 's|^-||' -e 's|-$||')"
  if [ -z "$slug" ]; then key="repo-$h"; else key="$slug$suffix"; fi
  printf '%s\n' "$key"
}

# sdlc_memory_root [<start-dir>] -> the absolute memory root, no trailing slash.
sdlc_memory_root() {
  local start="${1:-$PWD}" r xdg key
  if [ -n "${SDLC_MEMORY_ROOT:-}" ]; then
    case "$SDLC_MEMORY_ROOT" in
      /*) : ;;
      *)  printf 'memory-root.sh: SDLC_MEMORY_ROOT must be an absolute path\n' >&2; return 1 ;;
    esac
    r="$SDLC_MEMORY_ROOT"
    while [ "$r" != "/" ] && [ "${r%/}" != "$r" ]; do r="${r%/}"; done
    printf '%s\n' "$r"
    return 0
  fi
  # A relative XDG_DATA_HOME is IGNORED (treated as unset) per the XDG Base Directory spec —
  # deliberately unlike SDLC_MEMORY_ROOT, which hard-fails.
  case "${XDG_DATA_HOME:-}" in
    /*) xdg="$XDG_DATA_HOME" ;;
    *)  if [ -z "${HOME:-}" ]; then
          printf 'memory-root.sh: neither XDG_DATA_HOME (absolute) nor HOME is set — cannot resolve the memory root\n' >&2
          return 1
        fi
        xdg="${HOME}/.local/share" ;;
  esac
  key="$(sdlc_repo_key "$start")" || return 1
  printf '%s/sdlc/memories/%s\n' "$xdg" "$key"
}

# sdlc_memory_ensure <root> — create the layout under <root>, idempotently. Never called on source.
sdlc_memory_ensure() {
  local root="${1:-}"
  [ -n "$root" ] || {
    printf 'memory-root.sh: sdlc_memory_ensure needs a <root> argument\n' >&2
    return 1
  }
  # Probe every ancestor `mkdir -p` below would need BEFORE calling it: POSIX mkdir -p processes
  # each operand independently and continues past a failed one, so a single blocked sub-path (e.g.
  # <root>/captured already existing as a regular file) would otherwise leave a PARTIAL layout —
  # some of the four directories created, some not — contradicting the "creates nothing partially"
  # contract.
  local p blocked=""
  for p in "$root" "$root/agents" "$root/agents/shared" "$root/reviews" \
           "$root/captured" "$root/captured/rules" "$root/captured/reviews"; do
    [ -e "$p" ] && [ ! -d "$p" ] && blocked="$blocked $p"
  done
  if [ -n "$blocked" ]; then
    printf 'memory-root.sh: cannot create the memory layout under %s — a path segment is a file, not a directory:%s\n' "$root" "$blocked" >&2
    return 1
  fi
  mkdir -p "$root/agents/shared" "$root/reviews" "$root/captured/rules" "$root/captured/reviews" 2>/dev/null || {
    printf 'memory-root.sh: cannot create the memory layout under %s — check permissions and that no path segment is a file\n' "$root" >&2
    return 1
  }
  if [ ! -f "$root/captured/.gitignore" ]; then
    printf '*\n!.gitignore\n' > "$root/captured/.gitignore" 2>/dev/null || {
      printf 'memory-root.sh: cannot write the ignore marker in %s/captured\n' "$root" >&2
      return 1
    }
  fi
  return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -uo pipefail
  case "${1:-}" in
    --print-root) sdlc_memory_root || exit 1 ;;
    --print-key)  sdlc_repo_key    || exit 1 ;;
    --ensure)     root="$(sdlc_memory_root)" || exit 1
                  sdlc_memory_ensure "$root" || exit 1
                  printf '%s\n' "$root" ;;
    *) printf 'usage: memory-root.sh --print-root|--print-key|--ensure\n' >&2; exit 1 ;;
  esac
fi
