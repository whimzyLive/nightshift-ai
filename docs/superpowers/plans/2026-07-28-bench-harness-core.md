# Benchmark Harness Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `plugins/bench` far enough to run one benchmark cell — direct Opus on a real ticket — end to end, producing a measured cost/quality report.

**Architecture:** A Claude Code plugin whose scripts form a pipeline: `resolve` (ticket → story JSON) → `provision` (worktree) → `execute` (adapter hooks → `claude -p`) → `measure` (transcript → per-phase metrics) → `grade` (blinded diff → 3 graders) → `report` (aggregate markdown). Each stage reads and writes files on disk, so every stage is runnable and testable standalone. Approaches are declarative YAML, so adding one needs no code change.

**Tech Stack:** Python 3.9 (stdlib + PyYAML 6.0.3 only), bash, `claude` CLI 2.1.220, `acli`, `gh`, nx for versioning.

**Design doc:** `docs/superpowers/specs/2026-07-28-bench-harness-design.md`

## Global Constraints

- **Python 3.9.6.** No `match` statements. No PEP 604 unions (`int | None`) — use `Optional[int]`. PEP 585 builtin generics (`list[str]`) in annotations are fine.
- **Dependencies:** Python stdlib plus PyYAML only. No new package installs, no `requirements.txt`.
- **Test convention:** self-runnable, no framework. Python tests are `unittest` modules under `plugins/bench/scripts/__tests__/`, named `test_*.py`. One bash wrapper runs them all. Exit 0 = pass.
- **acli JSON is not pure JSON.** Always seek to the first `{` before decoding. Never `json.load(stdout)` directly.
- **acli cannot read custom fields via search.** `workitem search --fields customfield_10016` fails with `field 'customfield_10016' is not allowed`. Custom fields come only from `workitem view --fields '*all' --json`.
- **Branch safety:** every branch this harness creates is prefixed `bench/`. Any code path that pushes or writes a ref must assert that prefix first.
- **No merges.** No script in this plugin may invoke `gh pr merge`, `git merge`, or push to `develop` / `main`.
- **Plugin versioning is owned by `nx release`.** Never hand-edit `version` in `.claude-plugin/plugin.json`.
- **Cost source of truth:** `claude -p --output-format json` returns `total_cost_usd` and `modelUsage[<model>].costUSD`. Treat these as authoritative; reconstructed per-phase costs must reconcile against them within 2%.

---

### Task 1: Plugin scaffold and registration

**Files:**

- Create: `plugins/bench/.claude-plugin/plugin.json`
- Create: `plugins/bench/project.json`
- Create: `plugins/bench/README.md`
- Create: `plugins/bench/scripts/__tests__/run-python-tests.sh`
- Create: `plugins/bench/scripts/benchlib/__init__.py`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `nx.json:release.groups.plugins.projects`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**

- Consumes: nothing.
- Produces: the `bench` project name used by `nx release`; the test entrypoint `bash plugins/bench/scripts/__tests__/run-python-tests.sh` that every later task's tests run under.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_scaffold.py`:

```python
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PLUGIN = ROOT / "plugins" / "bench"


class TestScaffold(unittest.TestCase):
    def test_plugin_manifest_declares_name_bench(self):
        manifest = json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text())
        self.assertEqual(manifest["name"], "bench")

    def test_project_json_root_matches(self):
        project = json.loads((PLUGIN / "project.json").read_text())
        self.assertEqual(project["name"], "bench")
        self.assertEqual(project["root"], "plugins/bench")

    def test_registered_in_marketplace(self):
        market = json.loads((ROOT / ".claude-plugin" / "marketplace.json").read_text())
        names = [p["name"] for p in market["plugins"]]
        self.assertIn("bench", names)

    def test_registered_in_nx_release_group(self):
        nx = json.loads((ROOT / "nx.json").read_text())
        projects = nx["release"]["groups"]["plugins"]["projects"]
        self.assertIn("bench", projects)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `python3 -m unittest discover -s plugins/bench/scripts/__tests__ -v`
Expected: FAIL — the directory does not exist yet, or `plugin.json` is missing.

- [ ] **Step 3: Create the plugin manifest and project file**

`plugins/bench/.claude-plugin/plugin.json`:

```json
{
  "name": "bench",
  "version": "0.0.0",
  "description": "Benchmark harness — measures cost and delivered quality for implementing the same ticket through multiple approaches. Reads per-repo config from .claude/project/project-context.md.",
  "author": { "name": "nightshift" }
}
```

`plugins/bench/project.json`:

```json
{
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "name": "bench",
  "projectType": "library",
  "root": "plugins/bench",
  "targets": {}
}
```

`plugins/bench/scripts/benchlib/__init__.py`: empty file.

- [ ] **Step 4: Register the plugin**

In `.claude-plugin/marketplace.json`, append to the `plugins` array:

```json
{
  "name": "bench",
  "source": "./plugins/bench",
  "description": "Benchmark harness — measures cost and delivered quality for implementing the same ticket through multiple approaches"
}
```

In `nx.json`, add `"bench"` to `release.groups.plugins.projects` so it reads `["sdlc", "gtm", "bench"]`.

- [ ] **Step 5: Create the test wrapper**

`plugins/bench/scripts/__tests__/run-python-tests.sh`:

```bash
#!/usr/bin/env bash
# Runs every bench Python unittest module. Self-runnable, no framework:
#   bash plugins/bench/scripts/__tests__/run-python-tests.sh
# Exit 0 = all pass, non-zero = failure.
set -euo pipefail

here="${0%/*}"
[ "$here" = "$0" ] && here="."

python3 -m unittest discover -s "$here" -p 'test_*.py' -v
```

- [ ] **Step 6: Write the README**

`plugins/bench/README.md`:

```markdown
# bench

Measures cost and delivered quality for implementing the same ticket through multiple approaches.

Each approach is a declarative YAML file in `approaches/`. Adding one requires no code change.

## Commands

- `/bench:run <TICKET>` — run one or more approaches against a ticket
- `/bench:report <TICKET>` — regenerate the aggregate report from stored run data

## Pipeline

`resolve` → `provision` → `execute` → `measure` → `grade` → `report`

Each stage reads and writes files under `docs/benchmarks/<TICKET>/`, so any stage can be re-run
standalone without repeating the ones before it.

Design: `docs/superpowers/specs/2026-07-28-bench-harness-design.md`
```

- [ ] **Step 7: Wire into CI**

In `.github/workflows/ci.yml`, after the existing `bash plugins/sdlc/scripts/__tests__/docs-sync-fixtures.test.sh` line, add:

```yaml
      - run: bash plugins/bench/scripts/__tests__/run-python-tests.sh
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 9: Commit**

```bash
git add plugins/bench .claude-plugin/marketplace.json nx.json .github/workflows/ci.yml
git commit -m "feat(bench): scaffold plugin and register with marketplace and nx release"
```

---

### Task 2: acli wrapper

**Files:**

- Create: `plugins/bench/scripts/benchlib/acli.py`
- Test: `plugins/bench/scripts/__tests__/test_acli.py`

**Interfaces:**

- Consumes: nothing from earlier tasks.
- Produces:
  - `seek_json(raw: str) -> Any` — decode JSON that may be preceded by banner text.
  - `fetch_issue(key: str) -> dict` — the `fields` dict for one issue, all fields.
  - `issue_summary(fields: dict) -> str`
  - `issue_description(fields: dict) -> str` — ADF flattened to plain text.
  - `story_points(fields: dict, field_id: str) -> Optional[float]`

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_acli.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import acli  # noqa: E402


class TestSeekJson(unittest.TestCase):
    def test_decodes_plain_json(self):
        self.assertEqual(acli.seek_json('{"a": 1}'), {"a": 1})

    def test_skips_leading_banner(self):
        raw = 'Authenticated site: example.atlassian.net\n{"a": 1}'
        self.assertEqual(acli.seek_json(raw), {"a": 1})

    def test_decodes_leading_array(self):
        self.assertEqual(acli.seek_json("banner\n[1, 2]"), [1, 2])

    def test_raises_when_no_json_present(self):
        with self.assertRaises(ValueError):
            acli.seek_json("✗ Error: field not allowed")


class TestFieldExtraction(unittest.TestCase):
    def test_summary(self):
        self.assertEqual(acli.issue_summary({"summary": "Do a thing"}), "Do a thing")

    def test_story_points_reads_configured_field(self):
        fields = {"customfield_10016": 5}
        self.assertEqual(acli.story_points(fields, "customfield_10016"), 5)

    def test_story_points_missing_returns_none(self):
        self.assertIsNone(acli.story_points({}, "customfield_10016"))

    def test_description_flattens_adf(self):
        adf = {
            "type": "doc",
            "content": [
                {"type": "paragraph", "content": [{"type": "text", "text": "Hello"}]},
                {"type": "paragraph", "content": [{"type": "text", "text": "World"}]},
            ],
        }
        self.assertEqual(acli.issue_description({"description": adf}), "Hello\n\nWorld")

    def test_description_passes_through_plain_string(self):
        self.assertEqual(acli.issue_description({"description": "plain"}), "plain")

    def test_description_missing_returns_empty(self):
        self.assertEqual(acli.issue_description({}), "")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'benchlib.acli'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/benchlib/acli.py`:

```python
"""Thin acli wrapper.

Two constraints drive this module, both verified against whimzylive.atlassian.net:

1. acli's --json output is not always pure JSON; a banner line may precede it.
2. `workitem search --fields <customfield>` is rejected outright, so custom fields
   are only readable through `workitem view --fields '*all' --json`, one issue per call.
"""
import json
import subprocess
from typing import Any, List, Optional


class AcliError(RuntimeError):
    pass


def seek_json(raw: str) -> Any:
    """Decode JSON that may be preceded by banner text."""
    candidates = [i for i in (raw.find("{"), raw.find("[")) if i >= 0]
    if not candidates:
        raise ValueError("no JSON object or array found in acli output")
    return json.loads(raw[min(candidates):])


def run(args: List[str]) -> str:
    proc = subprocess.run(["acli"] + args, capture_output=True, text=True)
    if proc.returncode != 0:
        raise AcliError(f"acli {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc.stdout


def fetch_issue(key: str) -> dict:
    """Return the fields dict for one issue. Uses '*all' because custom fields
    are unavailable through any narrower field selection."""
    raw = run(["jira", "workitem", "view", key, "--fields", "*all", "--json"])
    return seek_json(raw).get("fields", {})


def issue_summary(fields: dict) -> str:
    return fields.get("summary") or ""


def _flatten_adf(node: Any, out: List[str]) -> None:
    if isinstance(node, dict):
        if node.get("type") == "text":
            out.append(node.get("text", ""))
        for child in node.get("content", []) or []:
            _flatten_adf(child, out)
        if node.get("type") in ("paragraph", "heading"):
            out.append("\n\n")
    elif isinstance(node, list):
        for child in node:
            _flatten_adf(child, out)


def issue_description(fields: dict) -> str:
    desc = fields.get("description")
    if desc is None:
        return ""
    if isinstance(desc, str):
        return desc
    parts: List[str] = []
    _flatten_adf(desc, parts)
    return "".join(parts).strip()


def story_points(fields: dict, field_id: str) -> Optional[float]:
    return fields.get(field_id)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 5: Verify against the live site**

Run:

```bash
python3 -c "
import sys; sys.path.insert(0, 'plugins/bench/scripts')
from benchlib import acli
f = acli.fetch_issue('NA-71')
print(acli.issue_summary(f))
print('points:', acli.story_points(f, 'customfield_10016'))
"
```

Expected: prints `Render marketing site as static build output` and `points: 5`.

- [ ] **Step 6: Commit**

```bash
git add plugins/bench/scripts/benchlib/acli.py plugins/bench/scripts/__tests__/test_acli.py
git commit -m "feat(bench): add acli wrapper with banner-tolerant JSON decoding"
```

---

### Task 3: Config resolution

**Files:**

- Create: `plugins/bench/scripts/benchlib/config.py`
- Test: `plugins/bench/scripts/__tests__/test_config.py`

**Interfaces:**

- Consumes: nothing from earlier tasks.
- Produces:
  - `BenchConfig` dataclass with fields `repo_root: Path`, `jira_site: str`, `jira_project: str`, `base_branch: str`, `test_command: str`, `package_manager: str`, `story_points_field: str`.
  - `parse_project_context(text: str) -> dict` — pulls values out of the markdown key/value tables.
  - `load_config(repo_root, overrides: dict) -> BenchConfig` — precedence: overrides, then project-context, then defaults.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_config.py`:

```python
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import config  # noqa: E402

SAMPLE = """
# Project Context

| Token            | Value                        |
| ---------------- | ---------------------------- |
| Project name     | nightshift-ai                |
| Jira project key | NA                           |
| Jira site        | whimzylive.atlassian.net     |
| Base branch      | develop                      |
| Package manager  | pnpm                         |
| Typecheck / Test | pnpm nx run-many -t test     |
"""


class TestParseProjectContext(unittest.TestCase):
    def test_extracts_known_tokens(self):
        parsed = config.parse_project_context(SAMPLE)
        self.assertEqual(parsed["Jira site"], "whimzylive.atlassian.net")
        self.assertEqual(parsed["Jira project key"], "NA")
        self.assertEqual(parsed["Base branch"], "develop")
        self.assertEqual(parsed["Typecheck / Test"], "pnpm nx run-many -t test")

    def test_ignores_table_separator_rows(self):
        parsed = config.parse_project_context(SAMPLE)
        self.assertNotIn("----------------", parsed)
        self.assertNotIn("Token", parsed)


class TestLoadConfig(unittest.TestCase):
    def _repo_with_context(self, text):
        tmp = Path(tempfile.mkdtemp())
        ctx = tmp / ".claude" / "project"
        ctx.mkdir(parents=True)
        (ctx / "project-context.md").write_text(text)
        return tmp

    def test_reads_from_project_context(self):
        repo = self._repo_with_context(SAMPLE)
        cfg = config.load_config(repo, {})
        self.assertEqual(cfg.jira_site, "whimzylive.atlassian.net")
        self.assertEqual(cfg.jira_project, "NA")
        self.assertEqual(cfg.base_branch, "develop")

    def test_overrides_beat_project_context(self):
        repo = self._repo_with_context(SAMPLE)
        cfg = config.load_config(repo, {"base_branch": "main"})
        self.assertEqual(cfg.base_branch, "main")

    def test_defaults_apply_without_project_context(self):
        tmp = Path(tempfile.mkdtemp())
        cfg = config.load_config(tmp, {})
        self.assertEqual(cfg.base_branch, "main")
        self.assertEqual(cfg.story_points_field, "customfield_10016")

    def test_story_points_field_is_not_discoverable_so_defaults(self):
        repo = self._repo_with_context(SAMPLE)
        cfg = config.load_config(repo, {})
        self.assertEqual(cfg.story_points_field, "customfield_10016")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'benchlib.config'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/benchlib/config.py`:

```python
"""Bench configuration.

Precedence: explicit overrides, then .claude/project/project-context.md, then defaults.

story_points_field has no discovery route. `acli jira field` exposes create/delete/update/
restore but no list, and `workitem view --json` carries no names map, so a field name cannot
be resolved to an ID on an arbitrary site. It is configuration, with Jira Cloud's usual
default as the fallback.
"""
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict

CONTEXT_PATH = Path(".claude") / "project" / "project-context.md"
DEFAULT_STORY_POINTS_FIELD = "customfield_10016"

_ROW = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|")


@dataclass
class BenchConfig:
    repo_root: Path
    jira_site: str
    jira_project: str
    base_branch: str
    test_command: str
    package_manager: str
    story_points_field: str


def parse_project_context(text: str) -> Dict[str, str]:
    """Extract key/value pairs from the markdown tables in project-context.md."""
    out: Dict[str, str] = {}
    for line in text.splitlines():
        match = _ROW.match(line.strip())
        if not match:
            continue
        key, value = match.group(1).strip(), match.group(2).strip()
        if not key or key == "Token" or set(key) <= set("- "):
            continue
        if set(value) <= set("- ") and value:
            continue
        out.setdefault(key, value)
    return out


def load_config(repo_root: Path, overrides: Dict[str, str]) -> BenchConfig:
    repo_root = Path(repo_root)
    context_file = repo_root / CONTEXT_PATH
    parsed = parse_project_context(context_file.read_text()) if context_file.exists() else {}

    def pick(override_key: str, context_key: str, default: str) -> str:
        if overrides.get(override_key):
            return overrides[override_key]
        return parsed.get(context_key) or default

    return BenchConfig(
        repo_root=repo_root,
        jira_site=pick("jira_site", "Jira site", ""),
        jira_project=pick("jira_project", "Jira project key", ""),
        base_branch=pick("base_branch", "Base branch", "main"),
        test_command=pick("test_command", "Typecheck / Test", ""),
        package_manager=pick("package_manager", "Package manager", "npm"),
        story_points_field=pick(
            "story_points_field", "Story points field", DEFAULT_STORY_POINTS_FIELD
        ),
    )
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add plugins/bench/scripts/benchlib/config.py plugins/bench/scripts/__tests__/test_config.py
git commit -m "feat(bench): resolve config from flags, project-context, then defaults"
```

---

### Task 4: Adapter loading and the opus adapter

**Files:**

- Create: `plugins/bench/scripts/benchlib/adapters.py`
- Create: `plugins/bench/approaches/opus.yaml`
- Test: `plugins/bench/scripts/__tests__/test_adapters.py`

**Interfaces:**

- Consumes: nothing from earlier tasks.
- Produces:
  - `Phase` dataclass: `id: str`, `marker: str`.
  - `Adapter` dataclass: `id: str`, `label: str`, `setup: list`, `prompt: str`, `flags: list`, `phases: list`, `teardown: list`.
  - `load_adapter(path: Path) -> Adapter`
  - `render(template: str, variables: dict) -> str` — `{{name}}` substitution only, no shell evaluation.
  - `ALLOWED_VARS: set` — the fixed variable set adapters may reference.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_adapters.py`:

```python
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchlib import adapters  # noqa: E402

YAML = """
id: demo
label: Demo Approach
setup:
  - echo setting up
run:
  prompt: |
    Implement {{ticket_key}}: {{ticket_summary}}
  flags: ["--permission-mode", "acceptEdits"]
phases:
  - {id: impl, marker: "/implement"}
teardown:
  - echo tearing down
"""


def _write(text):
    path = Path(tempfile.mkdtemp()) / "demo.yaml"
    path.write_text(text)
    return path


class TestLoadAdapter(unittest.TestCase):
    def test_loads_all_fields(self):
        adapter = adapters.load_adapter(_write(YAML))
        self.assertEqual(adapter.id, "demo")
        self.assertEqual(adapter.label, "Demo Approach")
        self.assertEqual(adapter.setup, ["echo setting up"])
        self.assertEqual(adapter.flags, ["--permission-mode", "acceptEdits"])
        self.assertEqual(adapter.teardown, ["echo tearing down"])
        self.assertIn("{{ticket_key}}", adapter.prompt)

    def test_phases_parsed(self):
        adapter = adapters.load_adapter(_write(YAML))
        self.assertEqual(len(adapter.phases), 1)
        self.assertEqual(adapter.phases[0].id, "impl")
        self.assertEqual(adapter.phases[0].marker, "/implement")

    def test_missing_phases_defaults_to_single_impl_phase(self):
        adapter = adapters.load_adapter(_write("id: bare\nlabel: Bare\nrun:\n  prompt: hi\n"))
        self.assertEqual([p.id for p in adapter.phases], ["impl"])
        self.assertEqual(adapter.phases[0].marker, "")

    def test_missing_prompt_is_an_error(self):
        with self.assertRaises(ValueError):
            adapters.load_adapter(_write("id: bad\nlabel: Bad\n"))


class TestRender(unittest.TestCase):
    def test_substitutes_known_variables(self):
        out = adapters.render("do {{ticket_key}} now", {"ticket_key": "NA-1"})
        self.assertEqual(out, "do NA-1 now")

    def test_unknown_variable_is_an_error(self):
        with self.assertRaises(ValueError):
            adapters.render("{{not_a_var}}", {"ticket_key": "NA-1"})

    def test_does_not_evaluate_shell(self):
        out = adapters.render("{{ticket_summary}}", {"ticket_summary": "$(rm -rf /)"})
        self.assertEqual(out, "$(rm -rf /)")


class TestShippedAdapters(unittest.TestCase):
    def test_opus_adapter_loads_and_has_no_setup(self):
        root = Path(__file__).resolve().parents[2]
        adapter = adapters.load_adapter(root / "approaches" / "opus.yaml")
        self.assertEqual(adapter.id, "opus")
        self.assertEqual(adapter.setup, [])
        self.assertEqual([p.id for p in adapter.phases], ["impl"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'benchlib.adapters'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/benchlib/adapters.py`:

```python
"""Declarative approach adapters.

An approach is a YAML file, so adding one needs no code change. Templating is
{{name}} substitution over a fixed variable set — adapter text is never passed
through a shell evaluator.
"""
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List

import yaml

ALLOWED_VARS = {
    "ticket_key",
    "ticket_summary",
    "ticket_description",
    "ticket_acs",
    "worktree",
    "artifacts",
    "base_branch",
    "test_command",
}

_VAR = re.compile(r"\{\{(\w+)\}\}")


@dataclass
class Phase:
    id: str
    marker: str


@dataclass
class Adapter:
    id: str
    label: str
    prompt: str
    setup: List[str] = field(default_factory=list)
    flags: List[str] = field(default_factory=list)
    phases: List[Phase] = field(default_factory=list)
    teardown: List[str] = field(default_factory=list)


def load_adapter(path: Path) -> Adapter:
    data = yaml.safe_load(Path(path).read_text()) or {}
    run = data.get("run") or {}
    prompt = run.get("prompt")
    if not prompt:
        raise ValueError(f"adapter {path} has no run.prompt")

    phases = [Phase(id=p["id"], marker=p.get("marker", "")) for p in data.get("phases") or []]
    if not phases:
        phases = [Phase(id="impl", marker="")]

    return Adapter(
        id=data.get("id") or Path(path).stem,
        label=data.get("label") or data.get("id") or Path(path).stem,
        prompt=prompt,
        setup=list(data.get("setup") or []),
        flags=list(run.get("flags") or []),
        phases=phases,
        teardown=list(data.get("teardown") or []),
    )


def render(template: str, variables: Dict[str, str]) -> str:
    def replace(match):
        name = match.group(1)
        if name not in ALLOWED_VARS:
            raise ValueError(f"unknown adapter variable: {name}")
        return str(variables.get(name, ""))

    return _VAR.sub(replace, template)
```

- [ ] **Step 4: Write the opus adapter**

`plugins/bench/approaches/opus.yaml`:

```yaml
id: opus
label: Direct Opus, no framework
# No setup: this approach deliberately brings no tooling, no skills, no process.
setup: []
run:
  prompt: |
    Implement the following ticket in this repository.

    Ticket: {{ticket_key}} — {{ticket_summary}}

    {{ticket_description}}

    Acceptance criteria:
    {{ticket_acs}}

    Work on the current branch. Commit your changes when done.
    Run the test suite with: {{test_command}}
  flags: ["--permission-mode", "acceptEdits"]
# One measured phase. This approach has no spec, plan, review or docs ceremony —
# that absence is the thing being measured, not an omission in the adapter.
phases:
  - { id: impl, marker: "" }
teardown: []
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 6: Commit**

```bash
git add plugins/bench/scripts/benchlib/adapters.py plugins/bench/approaches/opus.yaml plugins/bench/scripts/__tests__/test_adapters.py
git commit -m "feat(bench): add declarative adapter loader and direct-opus approach"
```

---

### Task 5: resolve.py — ticket to story JSON

**Files:**

- Create: `plugins/bench/scripts/resolve.py`
- Test: `plugins/bench/scripts/__tests__/test_resolve.py`

**Interfaces:**

- Consumes: `benchlib.acli`, `benchlib.config`.
- Produces: `story.json` on disk with keys `key`, `summary`, `description`, `acs`, `points`. Every later stage reads this file rather than calling acli again.
- Produces: `resolve.build_story(fields: dict, key: str, points_field: str) -> dict` and `resolve.extract_acs(description: str) -> str`.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_resolve.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import resolve  # noqa: E402


class TestExtractAcs(unittest.TestCase):
    def test_pulls_acceptance_criteria_section(self):
        desc = "Objective\nDo a thing.\nAcceptance criteria\n- one\n- two\nNon-goals\n- skip"
        self.assertEqual(resolve.extract_acs(desc), "- one\n- two")

    def test_case_insensitive_heading(self):
        desc = "ACCEPTANCE CRITERIA\n- only one"
        self.assertEqual(resolve.extract_acs(desc), "- only one")

    def test_missing_section_returns_empty(self):
        self.assertEqual(resolve.extract_acs("no criteria here"), "")


class TestBuildStory(unittest.TestCase):
    def test_builds_expected_shape(self):
        fields = {
            "summary": "Do a thing",
            "description": "Acceptance criteria\n- one",
            "customfield_10016": 3,
        }
        story = resolve.build_story(fields, "NA-9", "customfield_10016")
        self.assertEqual(story["key"], "NA-9")
        self.assertEqual(story["summary"], "Do a thing")
        self.assertEqual(story["points"], 3)
        self.assertEqual(story["acs"], "- one")

    def test_missing_points_is_none_not_an_error(self):
        story = resolve.build_story({"summary": "x"}, "NA-9", "customfield_10016")
        self.assertIsNone(story["points"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'resolve'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/resolve.py`:

```python
#!/usr/bin/env python3
"""Resolve a ticket into a normalised story document.

Usage:
  python3 resolve.py --key NA-80 --repo /path/to/repo --out story.json
"""
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import acli, config  # noqa: E402

_AC_HEADING = re.compile(r"^\s*acceptance criteria\s*:?\s*$", re.IGNORECASE)
_NEXT_HEADING = re.compile(
    r"^\s*(non-?goals?|notes?|prerequisites?|out of scope|objective)\s*:?\s*$", re.IGNORECASE
)


def extract_acs(description: str) -> str:
    lines = description.splitlines()
    collecting = False
    out = []
    for line in lines:
        if _AC_HEADING.match(line):
            collecting = True
            continue
        if collecting and _NEXT_HEADING.match(line):
            break
        if collecting:
            out.append(line)
    return "\n".join(out).strip()


def build_story(fields: dict, key: str, points_field: str) -> dict:
    description = acli.issue_description(fields)
    return {
        "key": key,
        "summary": acli.issue_summary(fields),
        "description": description,
        "acs": extract_acs(description),
        "points": acli.story_points(fields, points_field),
    }


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    cfg = config.load_config(Path(args.repo), {})
    fields = acli.fetch_issue(args.key)
    story = build_story(fields, args.key, cfg.story_points_field)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(story, indent=2))
    print(f"resolved {args.key} -> {out} (points={story['points']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 5: Verify against a live ticket**

Run:

```bash
python3 plugins/bench/scripts/resolve.py --key NA-68 --repo . --out /tmp/story.json && cat /tmp/story.json
```

Expected: prints `resolved NA-68 -> /tmp/story.json (points=3)` and the JSON contains a non-empty `acs`.

- [ ] **Step 6: Commit**

```bash
git add plugins/bench/scripts/resolve.py plugins/bench/scripts/__tests__/test_resolve.py
git commit -m "feat(bench): resolve a ticket into a normalised story document"
```

---

### Task 6: provision.py — worktree with branch-prefix guard

**Files:**

- Create: `plugins/bench/scripts/provision.py`
- Test: `plugins/bench/scripts/__tests__/test_provision.py`

**Interfaces:**

- Consumes: `benchlib.config`.
- Produces:
  - `branch_name(ticket: str, approach: str, run_id: str) -> str` — always `bench/<ticket>/<approach>/<run-id>`.
  - `assert_bench_branch(name: str) -> None` — raises `UnsafeBranchError` if the name is not under `bench/`.
  - `cell.json` on disk with keys `ticket`, `approach`, `run_id`, `branch`, `worktree`, `artifacts`, `base_sha`.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_provision.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import provision  # noqa: E402


class TestBranchName(unittest.TestCase):
    def test_always_prefixed_with_bench(self):
        name = provision.branch_name("NA-68", "opus", "r1")
        self.assertTrue(name.startswith("bench/"))
        self.assertEqual(name, "bench/NA-68/opus/r1")


class TestAssertBenchBranch(unittest.TestCase):
    def test_accepts_bench_branch(self):
        provision.assert_bench_branch("bench/NA-68/opus/r1")

    def test_rejects_develop(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("develop")

    def test_rejects_main(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("main")

    def test_rejects_lookalike_prefix(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("benchmarks/NA-68")

    def test_rejects_traversal(self):
        with self.assertRaises(provision.UnsafeBranchError):
            provision.assert_bench_branch("bench/../develop")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'provision'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/provision.py`:

```python
#!/usr/bin/env python3
"""Provision an isolated worktree for one benchmark cell.

Runs execute against the real repository, so the branch-prefix guard here is a
safety boundary, not a naming convention. Nothing in this plugin may write a ref
outside bench/.

Usage:
  python3 provision.py --story story.json --approach opus --run-id r1 \
      --repo /path/to/repo --out cell.json
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import config  # noqa: E402

BENCH_PREFIX = "bench/"


class UnsafeBranchError(RuntimeError):
    pass


def branch_name(ticket: str, approach: str, run_id: str) -> str:
    return f"{BENCH_PREFIX}{ticket}/{approach}/{run_id}"


def assert_bench_branch(name: str) -> None:
    if not name.startswith(BENCH_PREFIX):
        raise UnsafeBranchError(f"refusing to operate on non-bench branch: {name}")
    if ".." in name:
        raise UnsafeBranchError(f"refusing traversal in branch name: {name}")


def git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo)] + list(args), capture_output=True, text=True
    )
    if proc.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc.stdout.strip()


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--story", required=True)
    parser.add_argument("--approach", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--base-sha", default=None)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    cfg = config.load_config(repo, {})
    story = json.loads(Path(args.story).read_text())
    ticket = story["key"]

    branch = branch_name(ticket, args.approach, args.run_id)
    assert_bench_branch(branch)

    base_sha = args.base_sha or git(repo, "rev-parse", cfg.base_branch)
    worktree = repo / ".bench-worktrees" / f"{ticket}-{args.approach}-{args.run_id}"
    artifacts = repo / "docs" / "benchmarks" / ticket / args.approach / "artifacts"
    artifacts.mkdir(parents=True, exist_ok=True)

    git(repo, "worktree", "add", "-b", branch, str(worktree), base_sha)

    cell = {
        "ticket": ticket,
        "approach": args.approach,
        "run_id": args.run_id,
        "branch": branch,
        "worktree": str(worktree),
        "artifacts": str(artifacts),
        "base_sha": base_sha,
        "repo": str(repo),
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(cell, indent=2))
    print(f"provisioned {branch} at {worktree}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 5: Add the worktree directory to gitignore**

Append to `.gitignore`:

```
.bench-worktrees/
```

- [ ] **Step 6: Commit**

```bash
git add plugins/bench/scripts/provision.py plugins/bench/scripts/__tests__/test_provision.py .gitignore
git commit -m "feat(bench): provision isolated cell worktrees behind a branch-prefix guard"
```

---

### Task 7: execute.py — run the adapter

**Files:**

- Create: `plugins/bench/scripts/execute.py`
- Test: `plugins/bench/scripts/__tests__/test_execute.py`

**Interfaces:**

- Consumes: `benchlib.adapters`, `cell.json` from Task 6, `story.json` from Task 5.
- Produces:
  - `build_variables(cell: dict, story: dict, test_command: str, base_branch: str = "") -> dict`
  - `claude_argv(flags: list) -> list` — the exact argv used, so it is assertable in tests. The prompt goes in on stdin, not as an argument, so a long prompt cannot overflow the command line.
  - `result.json` on disk: the raw `claude -p --output-format json` payload plus `started_at`, `ended_at`, `setup_seconds`.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_execute.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import execute  # noqa: E402


class TestBuildVariables(unittest.TestCase):
    def test_maps_story_and_cell_fields(self):
        cell = {"worktree": "/w", "artifacts": "/a", "base_sha": "abc"}
        story = {"key": "NA-1", "summary": "S", "description": "D", "acs": "- a"}
        variables = execute.build_variables(cell, story, "pnpm test")
        self.assertEqual(variables["ticket_key"], "NA-1")
        self.assertEqual(variables["ticket_summary"], "S")
        self.assertEqual(variables["ticket_description"], "D")
        self.assertEqual(variables["ticket_acs"], "- a")
        self.assertEqual(variables["worktree"], "/w")
        self.assertEqual(variables["artifacts"], "/a")
        self.assertEqual(variables["test_command"], "pnpm test")


class TestClaudeArgv(unittest.TestCase):
    def test_always_prints_json(self):
        argv = execute.claude_argv([])
        self.assertIn("--print", argv)
        self.assertIn("--output-format", argv)
        self.assertIn("json", argv)

    def test_appends_adapter_flags(self):
        argv = execute.claude_argv(["--permission-mode", "acceptEdits"])
        self.assertIn("--permission-mode", argv)
        self.assertIn("acceptEdits", argv)

    def test_prompt_is_not_passed_as_an_argument(self):
        argv = execute.claude_argv([])
        self.assertNotIn("-p", argv)

    def test_never_bypasses_permissions(self):
        argv = execute.claude_argv([])
        self.assertNotIn("--dangerously-skip-permissions", argv)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'execute'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/execute.py`:

```python
#!/usr/bin/env python3
"""Execute one benchmark cell.

setup hooks run OUTSIDE the measured window. Installing a toolchain is a one-time
tax paid per machine, not a per-story cost, so charging it to the first story
would misrepresent the approach.

Usage:
  python3 execute.py --cell cell.json --story story.json \
      --adapter plugins/bench/approaches/opus.yaml --out result.json
"""
import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import adapters, config  # noqa: E402


def build_variables(
    cell: dict, story: dict, test_command: str, base_branch: str = ""
) -> Dict[str, str]:
    return {
        "ticket_key": story["key"],
        "ticket_summary": story["summary"],
        "ticket_description": story["description"],
        "ticket_acs": story["acs"],
        "worktree": cell["worktree"],
        "artifacts": cell["artifacts"],
        "base_branch": base_branch,
        "test_command": test_command,
    }


def claude_argv(flags: List[str]) -> List[str]:
    """The prompt is fed on stdin, never as an argv element — a long ticket
    description would otherwise risk the command-line length limit."""
    return [
        "claude",
        "--print",
        "--output-format",
        "json",
    ] + list(flags)


def run_hooks(commands: List[str], cwd: Path, variables: Dict[str, str]) -> None:
    for command in commands:
        rendered = adapters.render(command, variables)
        proc = subprocess.run(rendered, shell=True, cwd=str(cwd))
        if proc.returncode != 0:
            raise RuntimeError(f"hook failed ({proc.returncode}): {rendered}")


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cell", required=True)
    parser.add_argument("--story", required=True)
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    cell = json.loads(Path(args.cell).read_text())
    story = json.loads(Path(args.story).read_text())
    adapter = adapters.load_adapter(Path(args.adapter))
    cfg = config.load_config(Path(cell["repo"]), {})

    worktree = Path(cell["worktree"])
    variables = build_variables(cell, story, cfg.test_command, cfg.base_branch)

    setup_started = time.time()
    run_hooks(adapter.setup, worktree, variables)
    setup_seconds = time.time() - setup_started

    prompt = adapters.render(adapter.prompt, variables)
    # Archived for the record: the exact prompt is part of the run's evidence.
    Path(cell["artifacts"]).joinpath("prompt.txt").write_text(prompt)

    started_at = datetime.now(timezone.utc).isoformat()
    proc = subprocess.run(
        claude_argv(adapter.flags),
        cwd=str(worktree),
        input=prompt,
        capture_output=True,
        text=True,
    )
    ended_at = datetime.now(timezone.utc).isoformat()

    if proc.returncode != 0:
        Path(cell["artifacts"]).joinpath("claude.stderr").write_text(proc.stderr)
        raise RuntimeError(f"claude exited {proc.returncode}; stderr archived in artifacts")

    payload = json.loads(proc.stdout)
    payload["started_at"] = started_at
    payload["ended_at"] = ended_at
    payload["setup_seconds"] = round(setup_seconds, 3)

    run_hooks(adapter.teardown, worktree, variables)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2))
    print(
        "executed {0}: session={1} cost=${2:.4f}".format(
            adapter.id, payload.get("session_id"), payload.get("total_cost_usd", 0.0)
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add plugins/bench/scripts/execute.py plugins/bench/scripts/__tests__/test_execute.py
git commit -m "feat(bench): execute adapter hooks with setup outside the measured window"
```

---

### Task 8: measure.py — per-phase metrics and reconciliation

**Files:**

- Create: `plugins/bench/scripts/benchlib/pricing.json`
- Create: `plugins/bench/scripts/measure.py`
- Test: `plugins/bench/scripts/__tests__/test_measure.py`

**Interfaces:**

- Consumes: `result.json` from Task 7.
- Produces:
  - `find_transcript(session_id: str) -> Optional[Path]`
  - `assign_phases(entries: list, phases: list) -> list` — each entry tagged with a phase id.
  - `price_entry(usage: dict, model: str, pricing: dict) -> float`
  - `instruction_floor(residents: list) -> int` — minimum resident context.
  - `reconcile(computed: float, reported: float, tolerance: float = 0.02) -> bool`
  - `run.json` on disk with `total`, `by_phase`, `reconciliation`, `work_done`.

Pricing table values are per **million** tokens.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_measure.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import measure  # noqa: E402

PRICING = {
    "claude-opus-5": {
        "input": 5.0,
        "output": 25.0,
        "cache_write": 6.25,
        "cache_read": 0.5,
    }
}


class TestPriceEntry(unittest.TestCase):
    def test_prices_all_four_token_classes(self):
        usage = {
            "input_tokens": 1_000_000,
            "output_tokens": 1_000_000,
            "cache_creation_input_tokens": 1_000_000,
            "cache_read_input_tokens": 1_000_000,
        }
        self.assertAlmostEqual(
            measure.price_entry(usage, "claude-opus-5", PRICING), 36.75, places=4
        )

    def test_strips_context_window_suffix_from_model_id(self):
        usage = {"input_tokens": 1_000_000}
        self.assertAlmostEqual(
            measure.price_entry(usage, "claude-opus-5[1m]", PRICING), 5.0, places=4
        )

    def test_unknown_model_raises(self):
        with self.assertRaises(KeyError):
            measure.price_entry({"input_tokens": 1}, "not-a-model", PRICING)


class TestAssignPhases(unittest.TestCase):
    def _phase(self, pid, marker):
        return {"id": pid, "marker": marker}

    def test_single_phase_when_no_markers(self):
        entries = [{"type": "assistant", "text": "x"}, {"type": "assistant", "text": "y"}]
        tagged = measure.assign_phases(entries, [self._phase("impl", "")])
        self.assertEqual([e["phase"] for e in tagged], ["impl", "impl"])

    def test_switches_phase_on_marker(self):
        entries = [
            {"type": "user", "text": "/sdlc:impl go"},
            {"type": "assistant", "text": "working"},
            {"type": "user", "text": "/sdlc:review now"},
            {"type": "assistant", "text": "reviewing"},
        ]
        phases = [self._phase("impl", "/sdlc:impl"), self._phase("review-fix", "/sdlc:review")]
        tagged = measure.assign_phases(entries, phases)
        self.assertEqual([e["phase"] for e in tagged], ["impl", "impl", "review-fix", "review-fix"])

    def test_entries_before_any_marker_go_to_first_phase(self):
        entries = [{"type": "assistant", "text": "preamble"}]
        phases = [self._phase("impl", "/sdlc:impl"), self._phase("review-fix", "/sdlc:review")]
        tagged = measure.assign_phases(entries, phases)
        self.assertEqual(tagged[0]["phase"], "impl")

    def test_regex_alternation_in_marker(self):
        entries = [{"type": "user", "text": "/sdlc:review-fix"}]
        phases = [self._phase("impl", ""), self._phase("rf", "/sdlc:review|/sdlc:review-fix")]
        tagged = measure.assign_phases(entries, phases)
        self.assertEqual(tagged[0]["phase"], "rf")


class TestInstructionFloor(unittest.TestCase):
    def test_floor_is_the_minimum_resident_context(self):
        self.assertEqual(measure.instruction_floor([15000, 22000, 31000]), 15000)

    def test_empty_returns_zero(self):
        self.assertEqual(measure.instruction_floor([]), 0)


class TestReconcile(unittest.TestCase):
    def test_within_tolerance_passes(self):
        self.assertTrue(measure.reconcile(100.0, 101.0))

    def test_outside_tolerance_fails(self):
        self.assertFalse(measure.reconcile(100.0, 110.0))

    def test_zero_reported_is_not_a_division_error(self):
        self.assertFalse(measure.reconcile(1.0, 0.0))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'measure'`.

- [ ] **Step 3: Write the pricing table**

`plugins/bench/scripts/benchlib/pricing.json` — USD per million tokens. Keys are canonical model
ids; `measure.py` strips any `[...]` context-window suffix before lookup.

```json
{
  "claude-opus-5": { "input": 5.0, "output": 25.0, "cache_write": 6.25, "cache_read": 0.5 },
  "claude-sonnet-5": { "input": 3.0, "output": 15.0, "cache_write": 3.75, "cache_read": 0.3 },
  "claude-haiku-4-5-20251001": {
    "input": 1.0,
    "output": 5.0,
    "cache_write": 1.25,
    "cache_read": 0.1
  }
}
```

- [ ] **Step 4: Write the implementation**

`plugins/bench/scripts/measure.py`:

```python
#!/usr/bin/env python3
"""Turn a session transcript into per-phase cost and token metrics.

claude -p --output-format json reports total_cost_usd and modelUsage[<model>].costUSD,
which are authoritative. Those totals cannot be split across phases, so per-phase figures
are reconstructed from the transcript and then reconciled against the reported total.
A run whose reconstruction drifts past tolerance is flagged, never silently reported.

Usage:
  python3 measure.py --cell cell.json --result result.json \
      --adapter plugins/bench/approaches/opus.yaml --out run.json
"""
import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from benchlib import adapters  # noqa: E402

PRICING_PATH = Path(__file__).resolve().parent / "benchlib" / "pricing.json"
PROJECTS_DIR = Path.home() / ".claude" / "projects"
_SUFFIX = re.compile(r"\[.*\]$")


def load_pricing() -> dict:
    return json.loads(PRICING_PATH.read_text())


def price_entry(usage: dict, model: str, pricing: dict) -> float:
    canonical = _SUFFIX.sub("", model or "")
    rates = pricing[canonical]
    return (
        usage.get("input_tokens", 0) * rates["input"]
        + usage.get("output_tokens", 0) * rates["output"]
        + usage.get("cache_creation_input_tokens", 0) * rates["cache_write"]
        + usage.get("cache_read_input_tokens", 0) * rates["cache_read"]
    ) / 1_000_000


def find_transcript(session_id: str) -> Optional[Path]:
    matches = list(PROJECTS_DIR.glob(f"*/{session_id}.jsonl"))
    return matches[0] if matches else None


def read_entries(transcript: Path) -> List[dict]:
    entries = []
    for line in transcript.read_text().splitlines():
        if not line.strip():
            continue
        raw = json.loads(line)
        message = raw.get("message") or {}
        content = message.get("content")
        if isinstance(content, list):
            text = " ".join(
                part.get("text", "") for part in content if isinstance(part, dict)
            )
        else:
            text = str(content or "")
        entries.append(
            {
                "type": raw.get("type"),
                "text": text,
                "model": message.get("model"),
                "usage": message.get("usage") or {},
                "is_sidechain": bool(raw.get("isSidechain")),
                "timestamp": raw.get("timestamp"),
            }
        )
    return entries


def assign_phases(entries: List[dict], phases: List[dict]) -> List[dict]:
    """Tag each entry with the phase whose marker most recently fired.

    Entries before any marker belong to the first declared phase, so preamble
    work is never dropped from the accounting.
    """
    compiled = [(p["id"], re.compile(p["marker"]) if p.get("marker") else None) for p in phases]
    current = phases[0]["id"] if phases else "impl"
    out = []
    for entry in entries:
        for phase_id, pattern in compiled:
            if pattern is not None and pattern.search(entry.get("text") or ""):
                current = phase_id
                break
        tagged = dict(entry)
        tagged["phase"] = current
        out.append(tagged)
    return out


def instruction_floor(residents: List[int]) -> int:
    return min(residents) if residents else 0


def reconcile(computed: float, reported: float, tolerance: float = 0.02) -> bool:
    if reported <= 0:
        return False
    return abs(computed - reported) / reported <= tolerance


def summarise(entries: List[dict], pricing: dict) -> dict:
    by_phase: Dict[str, dict] = {}
    residents: List[int] = []
    for entry in entries:
        if entry["type"] != "assistant":
            continue
        usage = entry["usage"]
        bucket = by_phase.setdefault(
            entry["phase"],
            {
                "cost_usd": 0.0,
                "requests": 0,
                "input_tokens": 0,
                "output_tokens": 0,
                "cache_write_tokens": 0,
                "cache_read_tokens": 0,
                "subagent_requests": 0,
            },
        )
        bucket["cost_usd"] += price_entry(usage, entry["model"], pricing)
        bucket["requests"] += 1
        bucket["input_tokens"] += usage.get("input_tokens", 0)
        bucket["output_tokens"] += usage.get("output_tokens", 0)
        bucket["cache_write_tokens"] += usage.get("cache_creation_input_tokens", 0)
        bucket["cache_read_tokens"] += usage.get("cache_read_input_tokens", 0)
        if entry["is_sidechain"]:
            bucket["subagent_requests"] += 1
        residents.append(
            usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
        )

    floor = instruction_floor(residents)
    mean_resident = sum(residents) / len(residents) if residents else 0
    return {
        "by_phase": by_phase,
        "context": {
            "instruction_floor_tokens": floor,
            "mean_resident_tokens": round(mean_resident),
            "peak_resident_tokens": max(residents) if residents else 0,
            "work_context_tokens": round(max(0.0, mean_resident - floor)),
        },
    }


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cell", required=True)
    parser.add_argument("--result", required=True)
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    cell = json.loads(Path(args.cell).read_text())
    result = json.loads(Path(args.result).read_text())
    adapter = adapters.load_adapter(Path(args.adapter))
    pricing = load_pricing()

    transcript = find_transcript(result["session_id"])
    if transcript is None:
        raise RuntimeError(f"no transcript found for session {result['session_id']}")

    phases = [{"id": p.id, "marker": p.marker} for p in adapter.phases]
    entries = assign_phases(read_entries(transcript), phases)
    summary = summarise(entries, pricing)

    computed = sum(bucket["cost_usd"] for bucket in summary["by_phase"].values())
    reported = float(result.get("total_cost_usd") or 0.0)
    ok = reconcile(computed, reported)

    run = {
        "ticket": cell["ticket"],
        "approach": cell["approach"],
        "run_id": cell["run_id"],
        "session_id": result["session_id"],
        "total": {
            "reported_cost_usd": reported,
            "computed_cost_usd": round(computed, 6),
            "duration_ms": result.get("duration_ms"),
            "setup_seconds": result.get("setup_seconds"),
            "num_turns": result.get("num_turns"),
        },
        "by_phase": summary["by_phase"],
        "context": summary["context"],
        "reconciliation": {
            "ok": ok,
            "tolerance": 0.02,
            "note": "" if ok else "computed cost drifted past tolerance; excluded from aggregates",
        },
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(run, indent=2))
    status = "ok" if ok else "RECONCILIATION FAILED"
    print(
        "measured {0}: reported=${1:.4f} computed=${2:.4f} [{3}]".format(
            cell["approach"], reported, computed, status
        )
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 6: Calibrate pricing against a real session**

The pricing table must reproduce a known `costUSD`. Run:

```bash
python3 -c "
import sys, json; sys.path.insert(0, 'plugins/bench/scripts')
import measure
pricing = measure.load_pricing()
# modelUsage payload shape from a real claude -p run
usage = {'input_tokens': 2, 'output_tokens': 4,
         'cache_creation_input_tokens': 14888, 'cache_read_input_tokens': 15185}
print('computed:', measure.price_entry(usage, 'claude-opus-5[1m]', pricing))
print('reported: 0.1565825')
"
```

If the two disagree by more than 2%, correct the rates in `pricing.json` — the reported figure is
authoritative. Record the corrected rates in the commit message.

- [ ] **Step 7: Commit**

```bash
git add plugins/bench/scripts/measure.py plugins/bench/scripts/benchlib/pricing.json plugins/bench/scripts/__tests__/test_measure.py
git commit -m "feat(bench): attribute cost per phase and reconcile against reported total"
```

---

### Task 9: grade.py — blinded quality grading

**Files:**

- Create: `plugins/bench/scripts/grade.py`
- Test: `plugins/bench/scripts/__tests__/test_grade.py`

**Interfaces:**

- Consumes: `cell.json`, `story.json`.
- Produces:
  - `STRIP_PATTERNS: list` — path globs excluded from the graded diff.
  - `filter_diff(diff_text: str) -> str` — drops file sections matching `STRIP_PATTERNS` and any commit trailers.
  - `cell_hash(cell: dict) -> str` — stable, approach-independent directory name.
  - `grader_prompt(acs: str, diff_text: str, tests_text: str) -> str` — the diff and test output are **inlined into the prompt**, not left on disk for the grader to open. A grader with file tools and a working directory could walk `..` into the real repository and identify the approach, which would defeat the blinding this module exists to enforce.
  - `reduce_verdicts(verdicts: list) -> dict` — median for scalars, at-least-two-of-three for booleans.
  - `grades.json` on disk.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_grade.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import grade  # noqa: E402

DIFF = """diff --git a/src/app.ts b/src/app.ts
index 111..222 100644
--- a/src/app.ts
+++ b/src/app.ts
@@ -1 +1 @@
-old
+new
diff --git a/docs/superpowers/plans/2026-01-01-thing.md b/docs/superpowers/plans/2026-01-01-thing.md
index 333..444 100644
--- a/docs/superpowers/plans/2026-01-01-thing.md
+++ b/docs/superpowers/plans/2026-01-01-thing.md
@@ -1 +1 @@
-a
+b
"""


class TestFilterDiff(unittest.TestCase):
    def test_keeps_source_files(self):
        self.assertIn("src/app.ts", grade.filter_diff(DIFF))

    def test_drops_plan_docs(self):
        self.assertNotIn("docs/superpowers/plans", grade.filter_diff(DIFF))

    def test_drops_spec_docs(self):
        diff = "diff --git a/docs/superpowers/specs/x.md b/docs/superpowers/specs/x.md\n+a\n"
        self.assertEqual(grade.filter_diff(diff).strip(), "")

    def test_drops_speckit_directory(self):
        diff = "diff --git a/.specify/memory.md b/.specify/memory.md\n+a\n"
        self.assertEqual(grade.filter_diff(diff).strip(), "")

    def test_strips_session_trailer(self):
        diff = "diff --git a/a.ts b/a.ts\n+Claude-Session: https://claude.ai/code/session_x\n+real\n"
        out = grade.filter_diff(diff)
        self.assertNotIn("Claude-Session", out)
        self.assertIn("real", out)


class TestCellHash(unittest.TestCase):
    def test_is_stable(self):
        cell = {"ticket": "NA-1", "approach": "opus", "run_id": "r1"}
        self.assertEqual(grade.cell_hash(cell), grade.cell_hash(dict(cell)))

    def test_does_not_leak_the_approach_name(self):
        cell = {"ticket": "NA-1", "approach": "sdlc", "run_id": "r1"}
        self.assertNotIn("sdlc", grade.cell_hash(cell))


class TestReduceVerdicts(unittest.TestCase):
    def test_majority_wins_for_booleans(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": False}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["met"])

    def test_records_disagreement(self):
        verdicts = [
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": True}]},
            {"acs": [{"id": "AC1", "met": False}]},
        ]
        reduced = grade.reduce_verdicts(verdicts)
        self.assertTrue(reduced["acs"]["AC1"]["disagreement"])

    def test_unanimous_is_not_disagreement(self):
        verdicts = [{"acs": [{"id": "AC1", "met": True}]}] * 3
        reduced = grade.reduce_verdicts(verdicts)
        self.assertFalse(reduced["acs"]["AC1"]["disagreement"])

    def test_findings_count_uses_median(self):
        verdicts = [
            {"acs": [], "findings": [1, 2, 3]},
            {"acs": [], "findings": [1]},
            {"acs": [], "findings": [1, 2]},
        ]
        self.assertEqual(grade.reduce_verdicts(verdicts)["findings_count"], 2)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'grade'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/grade.py`:

```python
#!/usr/bin/env python3
"""Grade a cell's output blind.

Blinding is structural: this script receives a hash-named directory and the
original acceptance criteria, and never learns which approach produced the diff.
Process artifacts are stripped from the graded diff but are preserved intact in
the cell's artifacts directory — a plan document is real output, it is simply not
evidence of code correctness.

Usage:
  python3 grade.py --cell cell.json --story story.json --out grades.json
"""
import argparse
import hashlib
import json
import re
import statistics
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

STRIP_PATTERNS = [
    "docs/superpowers/",
    "docs/features/",
    "docs/benchmarks/",
    ".specify/",
    "CHANGELOG.md",
]

_TRAILER = re.compile(r"^[+\-].*(Claude-Session:|Co-Authored-By:|claude\.ai/code/session)")
_FILE_HEADER = re.compile(r"^diff --git a/(\S+) b/(\S+)")

GRADER_COUNT = 3


def filter_diff(diff_text: str) -> str:
    """Drop process-artifact file sections and identifying trailers."""
    out: List[str] = []
    keeping = True
    for line in diff_text.splitlines():
        header = _FILE_HEADER.match(line)
        if header:
            path = header.group(1)
            keeping = not any(pattern in path for pattern in STRIP_PATTERNS)
        if not keeping:
            continue
        if _TRAILER.match(line):
            continue
        out.append(line)
    return "\n".join(out)


def cell_hash(cell: dict) -> str:
    seed = "{0}|{1}|{2}".format(cell["ticket"], cell["approach"], cell["run_id"])
    return "cell-" + hashlib.sha256(seed.encode()).hexdigest()[:8]


def grader_prompt(acs: str, diff_text: str, tests_text: str) -> str:
    """Everything the grader may see is inlined here.

    The alternative — pointing the grader at a directory and letting it read files —
    gives it a working directory it can escape. One `..` reaches the real repository,
    where branch names and plan documents identify the approach immediately.
    """
    return (
        "You are reviewing a code change. You do not know how it was produced, you have no way "
        "to find out, and you must not speculate about it.\n\n"
        "Acceptance criteria:\n{0}\n\n"
        "Test output:\n```\n{1}\n```\n\n"
        "Diff under review:\n```diff\n{2}\n```\n\n"
        "Reply with ONLY a JSON object, no prose, in this exact shape:\n"
        '{{"acs": [{{"id": "AC1", "met": true, "evidence": "quote from the diff"}}], '
        '"findings": [{{"severity": "high|medium|low", "summary": "one sentence"}}], '
        '"regressions": false, "first_fix_round_items": 0}}\n'
    ).format(acs, tests_text, diff_text)


def build_blind_dir(cell: dict, story: dict, base: Path) -> Path:
    target = base / cell_hash(cell)
    target.mkdir(parents=True, exist_ok=True)

    diff = subprocess.run(
        ["git", "-C", cell["worktree"], "diff", cell["base_sha"], "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    (target / "diff.patch").write_text(filter_diff(diff))
    (target / "acs.md").write_text(story["acs"])
    tests = Path(cell["artifacts"]) / "tests.txt"
    (target / "tests.txt").write_text(tests.read_text() if tests.exists() else "not run")
    return target


def run_grader(blind_dir: Path, acs: str) -> dict:
    diff_text = (blind_dir / "diff.patch").read_text()
    tests_text = (blind_dir / "tests.txt").read_text()
    proc = subprocess.run(
        ["claude", "--print", "--output-format", "json"],
        cwd=str(blind_dir),
        input=grader_prompt(acs, diff_text, tests_text),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"grader failed: {proc.stderr.strip()}")
    payload = json.loads(proc.stdout)
    text = payload.get("result", "")
    start = text.find("{")
    if start < 0:
        raise ValueError("grader returned no JSON object")
    return json.loads(text[start:])


def reduce_verdicts(verdicts: List[dict]) -> dict:
    acs: Dict[str, dict] = {}
    for verdict in verdicts:
        for item in verdict.get("acs") or []:
            acs.setdefault(item["id"], {"votes": [], "evidence": []})
            acs[item["id"]]["votes"].append(bool(item.get("met")))
            if item.get("evidence"):
                acs[item["id"]]["evidence"].append(item["evidence"])

    reduced_acs = {}
    for ac_id, data in acs.items():
        votes = data["votes"]
        met = sum(1 for v in votes if v) >= 2
        reduced_acs[ac_id] = {
            "met": met,
            "votes": votes,
            "disagreement": len(set(votes)) > 1,
            "evidence": data["evidence"][:1],
        }

    counts = [len(v.get("findings") or []) for v in verdicts]
    fix_items = [int(v.get("first_fix_round_items") or 0) for v in verdicts]
    regressions = [bool(v.get("regressions")) for v in verdicts]

    return {
        "acs": reduced_acs,
        "findings_count": int(statistics.median(counts)) if counts else 0,
        "first_fix_round_items": int(statistics.median(fix_items)) if fix_items else 0,
        "regressions": sum(1 for r in regressions if r) >= 2,
        "grader_count": len(verdicts),
    }


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cell", required=True)
    parser.add_argument("--story", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--graders", type=int, default=GRADER_COUNT)
    args = parser.parse_args(argv)

    cell = json.loads(Path(args.cell).read_text())
    story = json.loads(Path(args.story).read_text())

    blind_base = Path(cell["artifacts"]).parent / "blind"
    blind_dir = build_blind_dir(cell, story, blind_base)

    verdicts = [run_grader(blind_dir, story["acs"]) for _ in range(args.graders)]
    reduced = reduce_verdicts(verdicts)
    reduced["blind_dir"] = str(blind_dir)
    reduced["raw_verdicts"] = verdicts

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(reduced, indent=2))
    met = sum(1 for ac in reduced["acs"].values() if ac["met"])
    print(f"graded {blind_dir.name}: {met}/{len(reduced['acs'])} ACs met, "
          f"{reduced['findings_count']} findings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add plugins/bench/scripts/grade.py plugins/bench/scripts/__tests__/test_grade.py
git commit -m "feat(bench): grade cells blind with three independent graders"
```

---

### Task 10: report.py — aggregate markdown

**Files:**

- Create: `plugins/bench/scripts/report.py`
- Test: `plugins/bench/scripts/__tests__/test_report.py`

**Interfaces:**

- Consumes: every `run.json` and `grades.json` under `docs/benchmarks/<TICKET>/`.
- Produces:
  - `collect_runs(ticket_dir: Path) -> list`
  - `phase_rows(runs: list) -> list` — one row per approach with `impl`, `review-fix`, `ceremony` costs.
  - `artifact_inventory(runs: list) -> list`
  - `render_markdown(ticket, runs) -> str`

`ceremony` is the sum of every phase that is not `impl` and not `review-fix`.

- [ ] **Step 1: Write the failing test**

Create `plugins/bench/scripts/__tests__/test_report.py`:

```python
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import report  # noqa: E402

RUN = {
    "approach": "sdlc",
    "total": {"reported_cost_usd": 46.67, "duration_ms": 600000},
    "by_phase": {
        "spec": {"cost_usd": 3.0},
        "plan": {"cost_usd": 2.0},
        "impl": {"cost_usd": 30.0},
        "review-fix": {"cost_usd": 8.0},
        "docs": {"cost_usd": 3.67},
    },
    "reconciliation": {"ok": True},
    "grades": {"acs": {"AC1": {"met": True}}, "findings_count": 2},
}


class TestPhaseRows(unittest.TestCase):
    def test_splits_impl_review_and_ceremony(self):
        row = report.phase_rows([RUN])[0]
        self.assertAlmostEqual(row["impl"], 30.0)
        self.assertAlmostEqual(row["review_fix"], 8.0)
        self.assertAlmostEqual(row["ceremony"], 8.67)

    def test_approach_without_ceremony_reports_zero(self):
        run = {
            "approach": "opus",
            "total": {"reported_cost_usd": 9.71, "duration_ms": 1},
            "by_phase": {"impl": {"cost_usd": 9.71}},
            "reconciliation": {"ok": True},
            "grades": {"acs": {}, "findings_count": 0},
        }
        row = report.phase_rows([run])[0]
        self.assertEqual(row["ceremony"], 0.0)
        self.assertEqual(row["review_fix"], 0.0)


class TestRenderMarkdown(unittest.TestCase):
    def test_includes_all_three_cost_rows(self):
        out = report.render_markdown("NA-80", [RUN])
        self.assertIn("impl-only", out)
        self.assertIn("review + fix", out)
        self.assertIn("ceremony", out)

    def test_flags_failed_reconciliation(self):
        run = dict(RUN)
        run["reconciliation"] = {"ok": False}
        self.assertIn("RECONCILIATION FAILED", report.render_markdown("NA-80", [run]))

    def test_clean_run_is_not_flagged(self):
        self.assertNotIn("RECONCILIATION FAILED", report.render_markdown("NA-80", [RUN]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: FAIL with `ModuleNotFoundError: No module named 'report'`.

- [ ] **Step 3: Write the implementation**

`plugins/bench/scripts/report.py`:

```python
#!/usr/bin/env python3
"""Render the aggregate comparison report.

Cost is never presented as a single number. impl-only is the apples-to-apples
figure; review+fix is what QA discipline costs; ceremony is spec/plan/docs.
Splitting them is what keeps the comparison fair to an approach that reviews its
own work against approaches that do not.

Usage:
  python3 report.py --ticket NA-80 --benchmarks docs/benchmarks --out docs/benchmarks/NA-80/report.md
"""
import argparse
import json
from pathlib import Path
from typing import List, Optional

IMPL = "impl"
REVIEW = "review-fix"


def collect_runs(ticket_dir: Path) -> List[dict]:
    runs = []
    for run_file in sorted(ticket_dir.glob("*/run.json")):
        run = json.loads(run_file.read_text())
        grades_file = run_file.parent / "grades.json"
        run["grades"] = json.loads(grades_file.read_text()) if grades_file.exists() else {}
        runs.append(run)
    return runs


def phase_rows(runs: List[dict]) -> List[dict]:
    rows = []
    for run in runs:
        phases = run.get("by_phase") or {}
        impl = float(phases.get(IMPL, {}).get("cost_usd", 0.0))
        review = float(phases.get(REVIEW, {}).get("cost_usd", 0.0))
        ceremony = sum(
            float(data.get("cost_usd", 0.0))
            for name, data in phases.items()
            if name not in (IMPL, REVIEW)
        )
        grades = run.get("grades") or {}
        acs = grades.get("acs") or {}
        rows.append(
            {
                "approach": run["approach"],
                "impl": impl,
                "review_fix": review,
                "ceremony": ceremony,
                "total": float(run["total"].get("reported_cost_usd", 0.0)),
                "duration_ms": run["total"].get("duration_ms") or 0,
                "acs_met": sum(1 for ac in acs.values() if ac.get("met")),
                "acs_total": len(acs),
                "findings": grades.get("findings_count", 0),
                "reconciled": bool((run.get("reconciliation") or {}).get("ok")),
            }
        )
    return rows


def artifact_inventory(runs: List[dict]) -> List[dict]:
    inventory = []
    for run in runs:
        phases = run.get("by_phase") or {}
        for name, data in phases.items():
            if name in (IMPL, REVIEW):
                continue
            inventory.append(
                {
                    "approach": run["approach"],
                    "phase": name,
                    "cost_usd": float(data.get("cost_usd", 0.0)),
                }
            )
    return inventory


def render_markdown(ticket: str, runs: List[dict]) -> str:
    rows = phase_rows(runs)
    lines = [
        f"# Benchmark: {ticket}",
        "",
        "Cost is split by phase. `impl-only` is the comparable figure across approaches;",
        "`review + fix` and `ceremony` are what the process-heavy approaches additionally buy.",
        "",
        "| Approach | impl-only $ | review + fix $ | ceremony $ | total $ | ACs met | findings | wall clock |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        flag = "" if row["reconciled"] else " **RECONCILIATION FAILED**"
        lines.append(
            "| {0}{1} | {2:.2f} | {3:.2f} | {4:.2f} | {5:.2f} | {6}/{7} | {8} | {9:.1f}s |".format(
                row["approach"],
                flag,
                row["impl"],
                row["review_fix"],
                row["ceremony"],
                row["total"],
                row["acs_met"],
                row["acs_total"],
                row["findings"],
                row["duration_ms"] / 1000.0,
            )
        )

    inventory = artifact_inventory(runs)
    if inventory:
        lines += [
            "",
            "## Artifact inventory",
            "",
            "What the ceremony spend bought.",
            "",
            "| Approach | Phase | Cost $ |",
            "| --- | --- | ---: |",
        ]
        for item in inventory:
            lines.append(
                "| {0} | {1} | {2:.2f} |".format(
                    item["approach"], item["phase"], item["cost_usd"]
                )
            )

    return "\n".join(lines) + "\n"


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ticket", required=True)
    parser.add_argument("--benchmarks", default="docs/benchmarks")
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    ticket_dir = Path(args.benchmarks) / args.ticket
    runs = collect_runs(ticket_dir)
    if not runs:
        raise RuntimeError(f"no runs found under {ticket_dir}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render_markdown(args.ticket, runs))
    print(f"wrote {out} ({len(runs)} runs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash plugins/bench/scripts/__tests__/run-python-tests.sh`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add plugins/bench/scripts/report.py plugins/bench/scripts/__tests__/test_report.py
git commit -m "feat(bench): render aggregate report with per-phase cost split"
```

---

### Task 11: Commands

**Files:**

- Create: `plugins/bench/commands/run.md`
- Create: `plugins/bench/commands/report.md`

**Interfaces:**

- Consumes: every script from Tasks 5–10.
- Produces: the `/bench:run` and `/bench:report` slash commands.

- [ ] **Step 1: Write the run command**

`plugins/bench/commands/run.md`:

````markdown
---
description: Run one or more benchmark approaches against a ticket and report measured cost and quality
---

Run the benchmark pipeline for a ticket.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly.

## Arguments

- `<TICKET>` — required, e.g. `NA-68`
- `--approaches <ids>` — comma-separated, default `opus`
- `--repo <path>` — default the current repository
- `--run-id <id>` — default a short timestamp-free counter supplied by the caller

## Safety

Runs execute against the real repository. Before dispatching, confirm with the founder:

- the ticket key and the approaches to run
- that branches will be created under `bench/` and never merged
- the estimated spend

Do not proceed without that confirmation.

## Steps

For each approach, in the order given:

1. Resolve the ticket.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/resolve.py" \
     --key <TICKET> --repo <REPO> --out docs/benchmarks/<TICKET>/story.json
   ```

2. Provision a worktree.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/provision.py" \
     --story docs/benchmarks/<TICKET>/story.json \
     --approach <APPROACH> --run-id <RUN_ID> --repo <REPO> \
     --out docs/benchmarks/<TICKET>/<APPROACH>/cell.json
   ```

3. Execute.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/execute.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<APPROACH>.yaml" \
     --out docs/benchmarks/<TICKET>/<APPROACH>/result.json
   ```

4. Measure. A non-zero exit means reconciliation failed — report it, do not hide it.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/measure.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --result docs/benchmarks/<TICKET>/<APPROACH>/result.json \
     --adapter "${CLAUDE_PLUGIN_ROOT}/approaches/<APPROACH>.yaml" \
     --out docs/benchmarks/<TICKET>/<APPROACH>/run.json
   ```

5. Grade.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/grade.py" \
     --cell docs/benchmarks/<TICKET>/<APPROACH>/cell.json \
     --story docs/benchmarks/<TICKET>/story.json \
     --out docs/benchmarks/<TICKET>/<APPROACH>/grades.json
   ```

Then render the report once, across every approach that ran:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/report.py" \
  --ticket <TICKET> --out docs/benchmarks/<TICKET>/report.md
```

Report the table to the founder. Never merge a bench branch. Never delete a worktree that failed —
its transcript is the evidence.
````

- [ ] **Step 2: Write the report command**

`plugins/bench/commands/report.md`:

````markdown
---
description: Regenerate the aggregate benchmark report for a ticket from stored run data
---

Regenerate the comparison report without re-running anything.

This command receives `${CLAUDE_PLUGIN_ROOT}` natively from the harness — use it directly.

## Arguments

- `<TICKET>` — required

## Steps

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/report.py" \
  --ticket <TICKET> --out docs/benchmarks/<TICKET>/report.md
```

Show the rendered table. If any row is flagged `RECONCILIATION FAILED`, say so explicitly and state
that the row is excluded from aggregate conclusions.
````

- [ ] **Step 3: Verify the plugin doc format check passes**

Run: `bash plugins/sdlc/scripts/check-plugin-docs-format.sh`
Expected: PASS. If it reports formatting problems in the new command files, fix them as reported.

- [ ] **Step 4: Commit**

```bash
git add plugins/bench/commands
git commit -m "feat(bench): add /bench:run and /bench:report commands"
```

---

### Task 12: Pilot cell — direct Opus, end to end

**Files:**

- Create: `docs/benchmarks/<TICKET>/` (generated)
- Modify: `docs/superpowers/specs/2026-07-28-bench-harness-design.md` (record pilot findings)

**Interfaces:**

- Consumes: everything above.
- Produces: a validated end-to-end run and a go/no-go recommendation for the remaining eleven cells.

- [ ] **Step 1: Confirm the pilot ticket with the founder**

Present the 3-point candidates and get an explicit choice. Confirm the estimated spend before
running anything. Do not pick unilaterally.

- [ ] **Step 2: Run the pipeline**

```bash
TICKET=<chosen>
python3 plugins/bench/scripts/resolve.py --key "$TICKET" --repo . \
  --out "docs/benchmarks/$TICKET/story.json"
python3 plugins/bench/scripts/provision.py --story "docs/benchmarks/$TICKET/story.json" \
  --approach opus --run-id r1 --repo . --out "docs/benchmarks/$TICKET/opus/cell.json"
python3 plugins/bench/scripts/execute.py --cell "docs/benchmarks/$TICKET/opus/cell.json" \
  --story "docs/benchmarks/$TICKET/story.json" \
  --adapter plugins/bench/approaches/opus.yaml \
  --out "docs/benchmarks/$TICKET/opus/result.json"
```

- [ ] **Step 3: Capture the test baseline and post-run result**

```bash
WT=$(python3 -c "import json;print(json.load(open('docs/benchmarks/$TICKET/opus/cell.json'))['worktree'])")
(cd "$WT" && pnpm nx run-many -t test) > "docs/benchmarks/$TICKET/opus/artifacts/tests.txt" 2>&1 || true
```

- [ ] **Step 4: Measure and check reconciliation**

```bash
python3 plugins/bench/scripts/measure.py --cell "docs/benchmarks/$TICKET/opus/cell.json" \
  --result "docs/benchmarks/$TICKET/opus/result.json" \
  --adapter plugins/bench/approaches/opus.yaml \
  --out "docs/benchmarks/$TICKET/opus/run.json"
```

Expected: exit 0 and `[ok]`. A non-zero exit means the pricing table is wrong — correct
`pricing.json` against the reported `modelUsage[<model>].costUSD` and re-run this step.

- [ ] **Step 5: Grade and verify blinding held**

```bash
python3 plugins/bench/scripts/grade.py --cell "docs/benchmarks/$TICKET/opus/cell.json" \
  --story "docs/benchmarks/$TICKET/story.json" \
  --out "docs/benchmarks/$TICKET/opus/grades.json"
grep -riE "sdlc|superpowers|spec-kit|specify|opus|approach" \
  "docs/benchmarks/$TICKET/blind/"*/diff.patch || echo "BLINDING OK: no approach identifiers"
```

Expected: `BLINDING OK`. Any hit means `STRIP_PATTERNS` needs another entry — add it, re-run
`grade.py`, and re-check before continuing.

- [ ] **Step 6: Render the report**

```bash
python3 plugins/bench/scripts/report.py --ticket "$TICKET" \
  --out "docs/benchmarks/$TICKET/report.md"
cat "docs/benchmarks/$TICKET/report.md"
```

Expected: one row, `impl-only` equal to total, `ceremony` and `review + fix` both `0.00`.

- [ ] **Step 7: Record findings in the design doc**

Add a `## Pilot findings` section to `docs/superpowers/specs/2026-07-28-bench-harness-design.md`
covering: measured cost versus the $9.71 direct-Opus floor estimate, whether reconciliation held
first try, whether blinding held first try, wall clock, and any correction made to `pricing.json`.

- [ ] **Step 8: Commit**

```bash
git add docs/benchmarks docs/superpowers/specs/2026-07-28-bench-harness-design.md
git commit -m "feat(bench): record direct-opus pilot cell results"
```

- [ ] **Step 9: Present the go/no-go**

Report to the founder: measured cost, whether every validation gate passed, and a recommendation on
whether to proceed to the remaining eleven cells. Do not start them without explicit approval.

---

## Out of scope for this plan

Plan 2, written after the pilot go/no-go, covers:

- `approaches/sdlc.yaml`, `approaches/superpowers.yaml`, `approaches/speckit.yaml`
- Scratch Jira issue provisioning (`bench-run` label, source-ticket link, key substitution)
- `cleanup.py` and `/bench:cleanup`
- The `PreToolUse` merge-deny hook (`hooks/hooks.json`, `hooks/deny-merge.sh`)
- Draft-PR enforcement
- Run-order counterbalancing across a full 12-cell sweep
- `--from-sha` replay mode and its contamination controls
