#!/usr/bin/env python3
"""docs_sync_fixture_gen.py — minimal, deterministic stand-in for the /sdlc:docs sync
resolver (refs/docs-pipeline.md §3), used only by docs-sync-fixtures.test.sh to prove the
activation-gated, family-resolved shape described in refs/doc-types.md and refs/docs-pipeline.md
against the three fixture repos (NA-65). This is a TEST HELPER, not the production algorithm —
the real algorithm is prose executed inline by the knowledge-engineer agent (see docs-pipeline.md's
"instructions not code" standing style). It implements just enough of the resolver ladder
(contract -> source -> scan -> skip) to be exercised mechanically and diffed against a committed
snapshot.

Usage:
  python3 docs_sync_fixture_gen.py <fixture-dir> <output-dir>

Reads <fixture-dir>/.claude/project/docs-manifest.md (row table + "## Reference roots" section)
and writes generated docs/reference/** + llms.txt into <output-dir>.
"""
import glob
import json
import os
import re
import sys

ARTIFACT_ROWS = {"command-reference", "agent-reference", "skill-reference", "hooks-contract"}
CONTRACT_ROWS = {"api-reference", "schema-reference", "config-reference"}
SOURCE_ONLY_ROWS = {"cli-reference", "error-reference"}

ARTIFACT_GLOB = {
    "command-reference": "commands/*.md",
    "agent-reference": "agents/*.md",
    "skill-reference": "skills/*/SKILL.md",
    "hooks-contract": "hooks/hooks.json",
}

CONTRACT_PATHS = {
    "api-reference": ["openapi.json", "openapi.yaml", "openapi.yml", "swagger.json"],
    "schema-reference": ["schema.json", "schema.graphql"],
    "config-reference": ["config.schema.json", ".env.schema", ".env.example"],
}


def unescape_md(text):
    # Undo the backslash-escaping the manifest applies so a glob like `*-template.md` survives
    # Prettier's table formatting without being read as emphasis markup.
    return re.sub(r"\\([*_|])", r"\1", text)


def parse_manifest(path):
    text = open(path).read()
    rows = {}
    in_table = False
    for line in text.splitlines():
        if line.strip().startswith("| type"):
            in_table = True
            continue
        if in_table:
            if not line.strip().startswith("|"):
                in_table = False
                continue
            if re.match(r"^\|[\s-]+\|", line):
                continue
            cells = [unescape_md(c.strip()) for c in line.strip().strip("|").split("|")]
            while len(cells) < 5:
                cells.append("")
            type_, enabled, target, source, contract = cells[:5]
            rows[type_] = {
                "enabled": enabled == "true",
                "target-path": target,
                "source": source,
                "contract": contract,
            }
    roots, excludes = [], []
    m = re.search(r"reference-roots:\s*(.*)", text)
    if m and m.group(1).strip():
        roots = [r.strip() for r in m.group(1).split(",") if r.strip()]
    m = re.search(r"reference-excludes:\s*(.*)", text)
    if m and m.group(1).strip():
        excludes = [r.strip() for r in m.group(1).split(",") if r.strip()]
    return rows, roots, excludes


def excluded(relpath, excludes):
    for ex in excludes:
        ex_norm = ex.rstrip("/")
        if relpath == ex_norm or relpath.startswith(ex_norm + "/"):
            return True
    return False


def parse_frontmatter(path):
    text = open(path).read()
    fm = {}
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            block = text[3:end].strip("\n")
            for line in block.splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    fm[k.strip()] = v.strip()
    return fm


def sanitize(text):
    return text.replace(" — ", ", ").replace("—", "-")


def write(output_dir, relpath, content):
    full = os.path.join(output_dir, relpath)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w") as f:
        f.write(content)


def gen_artifact_row(row_type, fixture_dir, roots, excludes, target, pages, output_dir):
    if not roots:
        return  # rung 4: skip — no page, no stub
    for root in roots:
        root_abs = os.path.join(fixture_dir, root)
        if not os.path.isdir(root_abs):
            raise SystemExit(f"FAIL LOUD: declared reference-roots entry missing: {root}")
        pattern = ARTIFACT_GLOB[row_type]
        for match in sorted(glob.glob(os.path.join(root_abs, pattern))):
            rel = os.path.relpath(match, fixture_dir)
            if excluded(rel, excludes):
                continue
            if row_type == "hooks-contract":
                title, desc = f"Hooks ({root})", "Hook contract registered by this root."
                title, desc = sanitize(title), sanitize(desc)
                body = f"# {title}\n\n{desc}\n\n**Source:** `{rel}`\n"
                out_rel = os.path.join(target, "index.md")
                write(output_dir, out_rel, body)
                pages.append({"path": out_rel, "title": title, "desc": desc})
                continue
            fm = parse_frontmatter(match)
            name = fm.get("name") or os.path.splitext(os.path.basename(match))[0]
            slug = (
                os.path.basename(os.path.dirname(match))
                if row_type == "skill-reference"
                else os.path.splitext(os.path.basename(match))[0]
            )
            desc = sanitize(fm.get("description", ""))
            title = sanitize(name if row_type != "command-reference" else f"/{name}")
            body_lines = [f"# {title}", "", desc, ""]
            if row_type == "command-reference" and fm.get("argument-hint"):
                body_lines += [f"**Usage:** `{fm['argument-hint']}`", ""]
            body_lines.append(f"**Source:** `{rel}`")
            body = "\n".join(body_lines) + "\n"
            out_rel = os.path.join(target, f"{slug}.md")
            write(output_dir, out_rel, body)
            pages.append({"path": out_rel, "title": title, "desc": desc})


def resolve_contract(row_type, fixture_dir, contract_cfg):
    if contract_cfg:
        p = os.path.join(fixture_dir, contract_cfg)
        if not os.path.isfile(p):
            raise SystemExit(f"FAIL LOUD: configured contract missing: {contract_cfg}")
        return contract_cfg
    for cand in CONTRACT_PATHS.get(row_type, []):
        if os.path.isfile(os.path.join(fixture_dir, cand)):
            return cand
    return None


def gen_contract_row(row_type, fixture_dir, row_cfg, target, pages, output_dir):
    contract_path = resolve_contract(row_type, fixture_dir, row_cfg["contract"])
    if contract_path:
        if row_type == "api-reference":
            spec = json.load(open(os.path.join(fixture_dir, contract_path)))
            api_title = sanitize(spec.get("info", {}).get("title", "API Reference"))
            lines = [f"# {api_title}", "", "## Endpoints", ""]
            for path, methods in sorted(spec.get("paths", {}).items()):
                for method, op in sorted(methods.items()):
                    summary = sanitize(op.get("summary", ""))
                    lines.append(f"- `{method.upper()} {path}`: {summary}")
            lines += ["", f"**Source:** `{contract_path}`"]
            body = "\n".join(lines) + "\n"
            title, desc = api_title, api_title
        else:
            title = row_type.replace("-", " ").title()
            body = f"# {title}\n\n**Source:** `{contract_path}`\n"
            desc = title
        out_rel = os.path.join(target, "index.md")
        write(output_dir, out_rel, body)
        pages.append({"path": out_rel, "title": title, "desc": desc})
        return
    if row_cfg["source"]:
        gen_source_row(row_type, fixture_dir, [], [], row_cfg, target, pages, output_dir)
    # else rung 4: skip


def gen_source_row(row_type, fixture_dir, roots, excludes, row_cfg, target, pages, output_dir):
    source = row_cfg["source"]
    if not source:
        return  # rung 4: skip

    if row_type == "error-reference":
        entries = []
        for root in roots:
            root_abs = os.path.join(fixture_dir, root)
            for sub in ("commands", "agents", "refs"):
                for match in sorted(
                    glob.glob(os.path.join(root_abs, sub, "**", "*.md"), recursive=True)
                ):
                    rel = os.path.relpath(match, fixture_dir)
                    if excluded(rel, excludes):
                        continue
                    text = open(match).read()
                    m = re.search(r"^##\s+Error Handling\s*$(.*?)(^##\s|\Z)", text, re.I | re.M | re.S)
                    if not m:
                        continue
                    for row in re.findall(r"^\|(?!\s*-)(.+)\|\s*$", m.group(1), re.M):
                        entries.append((rel, row.strip()))
        lines = ["# Error Reference", ""]
        for rel, row in entries:
            lines.append(f"- {row} (`{rel}`)")
        body = "\n".join(lines) + "\n"
        out_rel = os.path.join(target, "index.md")
        write(output_dir, out_rel, body)
        pages.append({"path": out_rel, "title": "Error Reference", "desc": "Aggregated Error Handling sections."})
        return

    if row_type == "config-reference":
        globbed = sorted(glob.glob(os.path.join(fixture_dir, source)))
        lines = ["# Config Reference", ""]
        for match in globbed:
            rel = os.path.relpath(match, fixture_dir)
            first_para = open(match).read().split("\n\n", 1)[0]
            lines += [
                f"## `{os.path.basename(match)}`",
                "",
                sanitize(first_para.strip()),
                "",
                f"**Source:** `{rel}`",
                "",
            ]
        body = "\n".join(lines) + "\n"
        out_rel = os.path.join(target, "index.md")
        write(output_dir, out_rel, body)
        pages.append({"path": out_rel, "title": "Config Reference", "desc": "Config surface a consumer must provide."})
        return

    if row_type == "cli-reference":
        body = f"# CLI Reference\n\n**Source:** `{source}`\n"
        out_rel = os.path.join(target, "index.md")
        write(output_dir, out_rel, body)
        pages.append({"path": out_rel, "title": "CLI Reference", "desc": "CLI surface documented from the configured source."})
        return


def main():
    fixture_dir, output_dir = sys.argv[1], sys.argv[2]
    manifest = os.path.join(fixture_dir, ".claude/project/docs-manifest.md")
    rows, roots, excludes = parse_manifest(manifest)
    pages = []

    for row_type, cfg in sorted(rows.items()):
        if row_type == "llms-txt" or not cfg["enabled"]:
            continue
        target = cfg["target-path"]
        if row_type in ARTIFACT_ROWS:
            gen_artifact_row(row_type, fixture_dir, roots, excludes, target, pages, output_dir)
        elif row_type in CONTRACT_ROWS:
            gen_contract_row(row_type, fixture_dir, cfg, target, pages, output_dir)
        elif row_type in SOURCE_ONLY_ROWS:
            gen_source_row(row_type, fixture_dir, roots, excludes, cfg, target, pages, output_dir)

    llms_cfg = rows.get("llms-txt")
    llms_target = llms_cfg["target-path"] if llms_cfg else "llms.txt"
    lines = ["# llms.txt", ""]
    if pages:
        lines.append("## reference")
        lines.append("")
        for p in sorted(pages, key=lambda p: p["path"]):
            lines.append(f"- {p['title']} - {p['desc']} - {p['path']}")
        lines.append("")
    else:
        lines += ["(no entries)", ""]
    write(output_dir, llms_target, "\n".join(lines).rstrip("\n") + "\n")


if __name__ == "__main__":
    main()
