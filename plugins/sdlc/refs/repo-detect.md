# Repository Detection Procedure

Use this ref whenever a command needs to determine the tech stack of the current repository
without running arbitrary code. All detection is **read-only** — only `cat`, `ls`, `find`, `git`,
and `grep` are used. Never execute build scripts or install dependencies.

## Output contract

Detection produces exactly these seven fields:

| Field             | Description                                                                         | Example values                                                         |
| ----------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `language`        | Primary language(s) — comma-separated if mixed                                      | `TypeScript`, `Python`, `Go`, `Rust`, `TypeScript, Python`             |
| `framework`       | Web/API framework(s) detected, or `none`                                            | `Next.js`, `Hono`, `FastAPI`, `none`                                   |
| `package_manager` | The package manager in use                                                          | `pnpm`, `npm`, `yarn`, `bun`, `cargo`, `poetry`, `uv`, `go`, `bundler` |
| `test_runner`     | Test command to run the suite                                                       | `pnpm test`, `pytest`, `cargo test`, `go test ./...`                   |
| `typecheck`       | Typecheck command, or empty string if not applicable                                | `pnpm typecheck`, `mypy .`, `pyright`, ``                              |
| `runtime`         | Language runtime + version where explicitly declared                                | `Node 20`, `Python 3.12`, `Go 1.22`, `Rust 2021`                       |
| `commit_scopes`   | Comma-separated valid conventional-commit scopes derived from workspace directories | `functions, config, web`                                               |

These field names are the canonical identifiers; `init.md` reads them by these exact names.

---

## Step 1 — Detect package manager (lockfile precedence)

Check lockfiles in the repo root in this exact priority order (first match wins):

```bash
for f in pnpm-lock.yaml yarn.lock bun.lockb package-lock.json Cargo.lock poetry.lock uv.lock go.sum Gemfile.lock; do
  [ -f "$f" ] && echo "LOCKFILE=$f" && break
done
```

Map the winning lockfile to `package_manager`:

| Lockfile            | `package_manager` |
| ------------------- | ----------------- |
| `pnpm-lock.yaml`    | `pnpm`            |
| `yarn.lock`         | `yarn`            |
| `bun.lockb`         | `bun`             |
| `package-lock.json` | `npm`             |
| `Cargo.lock`        | `cargo`           |
| `poetry.lock`       | `poetry`          |
| `uv.lock`           | `uv`              |
| `go.sum`            | `go`              |
| `Gemfile.lock`      | `bundler`         |

**Ambiguity rule:** if more than one lockfile exists at the same precedence tier (e.g. both
`yarn.lock` and `pnpm-lock.yaml`), surface the top-2 candidates to the user:

```
AskUserQuestion(
  header: "Multiple lockfiles found",
  question: "Which package manager does this project use?",
  multiSelect: false,
  options: [<candidate-1>, <candidate-2>]
)
```

---

## Step 2 — Detect language(s)

Primary language is inferred from the presence of language manifest files plus dominant source-file
extensions. Check in this order; a repo may qualify for more than one language:

```bash
# Manifest signals
[ -f package.json ]    && echo "CANDIDATE_LANG=TypeScript/JavaScript"
[ -f pyproject.toml ]  && echo "CANDIDATE_LANG=Python"
[ -f setup.py ]        && echo "CANDIDATE_LANG=Python"
[ -f Cargo.toml ]      && echo "CANDIDATE_LANG=Rust"
[ -f go.mod ]          && echo "CANDIDATE_LANG=Go"
find . -maxdepth 3 -name "*.csproj" -print -quit 2>/dev/null && echo "CANDIDATE_LANG=C#"
```

Refine JavaScript-vs-TypeScript for Node repos:

```bash
[ -f tsconfig.json ] && echo "LANG_NODE=TypeScript" || echo "LANG_NODE=JavaScript"
```

**Language precedence:** if `tsconfig.json` exists alongside `package.json`, report `TypeScript`,
not `TypeScript/JavaScript`.

For mixed repos (e.g. TS backend + Python ML layer), set `language` to both values
comma-separated: `TypeScript, Python`.

---

## Step 3 — Detect framework

Scan the dependency manifest(s) for known framework names. For Node repos, grep `package.json`:

```bash
grep -o '"next"\|"react"\|"vue"\|"svelte"\|"express"\|"hono"\|"fastify"\|"nestjs"\|"@nestjs/core"\|"remix"\|"astro"\|"nuxt"\|"elysia"' package.json 2>/dev/null | head -5
```

For Python repos, grep `pyproject.toml` or `requirements*.txt`:

```bash
grep -iE 'django|flask|fastapi|starlette|tornado|litestar' pyproject.toml setup.py requirements*.txt 2>/dev/null | head -5
```

For Rust repos, grep `Cargo.toml`:

```bash
grep -iE 'axum|actix|warp|rocket|poem' Cargo.toml 2>/dev/null | head -5
```

For Go repos, grep `go.mod`:

```bash
grep -iE 'gin|echo|fiber|chi|gorilla' go.mod 2>/dev/null | head -5
```

Map the first hit to a canonical `framework` label:

| Matched string            | `framework` label |
| ------------------------- | ----------------- |
| `next`                    | `Next.js`         |
| `react` (without next)    | `React`           |
| `vue`                     | `Vue`             |
| `svelte`                  | `Svelte`          |
| `nuxt`                    | `Nuxt`            |
| `astro`                   | `Astro`           |
| `remix`                   | `Remix`           |
| `express`                 | `Express`         |
| `hono`                    | `Hono`            |
| `fastify`                 | `Fastify`         |
| `nestjs` / `@nestjs/core` | `NestJS`          |
| `elysia`                  | `Elysia`          |
| `django`                  | `Django`          |
| `flask`                   | `Flask`           |
| `fastapi`                 | `FastAPI`         |
| `starlette`               | `Starlette`       |
| `axum`                    | `Axum`            |
| `actix`                   | `Actix`           |
| `gin`                     | `Gin`             |
| `echo`                    | `Echo`            |
| `fiber`                   | `Fiber`           |

If no framework is matched, set `framework` to `none`.

If more than one framework label matches (e.g. monorepo with Next.js + Hono), set `framework` to
all comma-separated: `Next.js, Hono`.

---

## Step 4 — Detect test runner

Check scripts in `package.json`, then fall back to installed devDependencies:

```bash
# Node repos — check package.json scripts first
grep -o '"test"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null | head -3

# Then check devDependencies / dependencies for test frameworks
grep -o '"vitest"\|"jest"\|"mocha"\|"jasmine"\|"ava"' package.json 2>/dev/null | head -3

# Check for Node built-in test runner (node:test)
grep -E '"test".*node.*--test' package.json 2>/dev/null | head -2
```

For Python repos:

```bash
grep -iE 'pytest|unittest|nose' pyproject.toml setup.py requirements*.txt 2>/dev/null | head -3
```

For Rust, Go: the test runner is the toolchain — no detection needed.

Map findings to `test_runner`:

| Signal                   | `test_runner` value                                 |
| ------------------------ | --------------------------------------------------- |
| `vitest` in deps         | `<pm> test` (e.g. `pnpm test`)                      |
| `jest` in deps           | `<pm> test`                                         |
| `node --test` in scripts | `node --import tsx --test` (if TS) or `node --test` |
| `mocha` in deps          | `<pm> test`                                         |
| `pytest` in deps/config  | `pytest`                                            |
| `Cargo.lock` present     | `cargo test`                                        |
| `go.sum` present         | `go test ./...`                                     |
| Script entry exists      | use the literal script value prefixed by `<pm> run` |

If none of the above is conclusive, set `test_runner` to an empty string and leave the
free-text prompt unprefilled so the user enters it manually.

---

## Step 5 — Detect typecheck command

```bash
# TypeScript — prefer a named script over raw tsc
[ -f tsconfig.json ] && grep -o '"typecheck"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null | head -1
[ -f tsconfig.json ] && grep -o '"type-check"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null | head -1

# Python
command -v mypy    >/dev/null 2>&1 && echo "TYPECHECK=mypy ."
command -v pyright >/dev/null 2>&1 && echo "TYPECHECK=pyright"
```

Map to `typecheck`:

| Signal                                   | `typecheck` value                        |
| ---------------------------------------- | ---------------------------------------- |
| `"typecheck"` script in package.json     | `<pm> typecheck` (e.g. `pnpm typecheck`) |
| `"type-check"` script in package.json    | `<pm> run type-check`                    |
| `tsconfig.json` present, no named script | `npx tsc --noEmit`                       |
| `mypy` available, Python repo            | `mypy .`                                 |
| `pyright` available, Python repo         | `pyright`                                |
| None of the above                        | `` (empty — leave blank in prompts)      |

---

## Step 6 — Detect runtime

Read the runtime version from version-declaration files only — do **not** probe the live environment
or execute any command. Check in this order:

```bash
# Node — .nvmrc (exact version string, e.g. "20.11.1" or "lts/iron")
[ -f .nvmrc ] && cat .nvmrc

# Node — package.json engines.node field
grep -o '"node"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null | head -1

# Python — .python-version (pyenv / mise)
[ -f .python-version ] && cat .python-version

# Python — pyproject.toml requires-python
grep -o 'requires-python[[:space:]]*=[[:space:]]*"[^"]*"' pyproject.toml 2>/dev/null | head -1

# Go — go.mod go directive (first line containing "^go ")
grep -m1 '^go ' go.mod 2>/dev/null

# Rust — Cargo.toml edition (edition field)
grep -o 'edition[[:space:]]*=[[:space:]]*"[^"]*"' Cargo.toml 2>/dev/null | head -1
```

Map the first matching signal to the `runtime` field:

| Signal                                         | `runtime` value                                                             |
| ---------------------------------------------- | --------------------------------------------------------------------------- |
| `.nvmrc` or `engines.node` present             | `Node <version>` (e.g. `Node 20`) — strip patch if only major/minor matters |
| `.python-version` or `requires-python` present | `Python <version>` (e.g. `Python 3.12`)                                     |
| `go.mod` `go` directive                        | `Go <version>` (e.g. `Go 1.22`)                                             |
| `Cargo.toml` `edition` field                   | `Rust <edition>` (e.g. `Rust 2021`)                                         |
| None of the above                              | `` (empty — do not guess)                                                   |

If no version declaration is found, leave `runtime` empty. Do **not** run `node --version`,
`python --version`, or any other live-environment probe.

---

## Step 7 — Detect commit scopes

Derive valid conventional-commit scopes from the immediate subdirectory names under `packages/`
and `apps/`:

```bash
find packages apps -maxdepth 1 -mindepth 1 -type d 2>/dev/null | xargs -I{} basename {} | sort | tr '\n' ',' | sed 's/,$//'
```

Collect the resulting names as a comma-separated list (e.g. `functions, config, web`).

If neither `packages/` nor `apps/` exists in the repo root, leave `commit_scopes` empty.
Do not descend deeper than one level — only immediate children of `packages/` or `apps/` count.

---

## Ambiguity rules (summary)

1. **Multiple lockfiles at same tier** → `AskUserQuestion` with the top-2 candidates.
2. **No lockfile found** → leave `package_manager` unprefilled; the Step-3 picker has no pre-selected default.
3. **No manifest match for language** → default to `unknown`; do not guess. Ask the user via a free-text question.
4. **No framework matched** → set `framework` to `none`; do not surface a question.
5. **Test runner inconclusive** → leave `test_runner` empty; the user fills the free-text field.
6. **Typecheck inconclusive** → leave `typecheck` empty; the user fills the free-text field.
7. **No runtime declaration found** → leave `runtime` empty; do not guess or probe the live environment.
8. **No `packages/` or `apps/` directory** → leave `commit_scopes` empty; do not infer from other paths.

In every ambiguous case, prefer surfacing a pre-filled suggestion the user can confirm over
asking a fully open question — reduce typing, never remove agency.
