# Product Info Detection Procedure

Used by `/gtm:init` Step 3. **Read-only** — only `cat`, `git`, `grep`, and simple JSON field reads
are used. Writes nothing. Resolve each field by the first matching source; anything left
unresolved becomes an interview gap that Step 4 (the marketingskills `product-marketing` skill)
fills.

## Output contract

| Field | Detection sources (in order) | Interview fallback |
| ----- | ---------------------------- | ------------------- |
| `name` | `package.json` `name` → git remote repo name → top-level `README.md` H1 | prompt |
| `one-liner` | `package.json` `description` → README tagline/subtitle → `brand/BRAND_KIT.md` tagline (when present) | prompt |
| `repo` | `git remote get-url origin` (normalized to `owner/name` or URL) | prompt |
| `landing URL` | `package.json` `homepage` → first external link/badge in `README.md` | prompt (blank allowed) |

`brand/` is **read-only** here — a detection source only; this command makes no changes under
`brand/`.

## Step 1 — `name`

```bash
[ -f package.json ] && grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1
git remote get-url origin 2>/dev/null | sed -E 's#.*/([^/.]+)(\.git)?$#\1#'
[ -f README.md ] && grep -m1 -E '^# ' README.md | sed -E 's/^# //'
```

First non-empty result wins. If none resolve, `name` is an interview gap.

## Step 2 — `one-liner`

```bash
[ -f package.json ] && grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1
[ -f README.md ] && sed -n '2,6p' README.md | grep -m1 -E '^[A-Za-z].{10,}'
[ -f brand/BRAND_KIT.md ] && grep -m1 -iE 'tagline' brand/BRAND_KIT.md
```

First non-empty result wins. If none resolve, `one-liner` is an interview gap.

## Step 3 — `repo`

```bash
git remote get-url origin 2>/dev/null
```

Normalize to `owner/name` when the remote is a GitHub-style URL (SSH or HTTPS); otherwise keep the
URL as-is. If no `origin` remote exists, `repo` is an interview gap — prompt for it (no guess).

## Step 4 — `landing URL`

```bash
[ -f package.json ] && grep -o '"homepage"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1
[ -f README.md ] && grep -m1 -oE 'https?://[^ )\]]+' README.md
```

First non-empty result wins. If none resolve, leave `landing URL` **blank** — it is not required;
do not prompt unless the founder wants to add one.

## Handoff to Step 4

Pass whatever was detected (including gaps) to the marketingskills `product-marketing` skill
invocation — it seeds the skill's auto-draft of `.agents/product-marketing.md` and, separately,
`/gtm:init`'s own `marketing-context.md` product fields in Step 5. Detected `repo`/`landing URL`
gaps become plain-text interview prompts (no picker — these are open string values).
