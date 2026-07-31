#!/usr/bin/env python3
import glob
import json
import os
import subprocess
import sys

DEFAULT_PROJECT_DIR = "-Users-Rushi-Development-EdgeTech-ai-workspace-nightshift"
DEFAULT_COUNT = 12


def transcript_root():
    return os.path.expanduser(os.path.join("~/.claude/projects", DEFAULT_PROJECT_DIR))


def recent_transcripts(count):
    files = glob.glob(os.path.join(transcript_root(), "*.jsonl"))
    files.sort(key=os.path.getmtime, reverse=True)
    return files[:count]


def read_corpus_list(list_path):
    base = os.path.dirname(os.path.abspath(list_path))
    paths = []
    with open(list_path, encoding="utf-8") as f:
        for raw in f:
            entry = raw.strip()
            if not entry or entry.startswith("#"):
                continue
            entry = os.path.expanduser(entry)
            if not os.path.isabs(entry):
                entry = os.path.join(base, entry)
            paths.append(entry)
    return paths


def load_corpus(paths):
    commands = []
    for path in paths:
        if not os.path.isfile(path):
            print("rtk-coverage: missing corpus file: %s" % os.path.abspath(path), file=sys.stderr)
            continue
        with open(path, encoding="utf-8", errors="ignore") as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    record = json.loads(raw)
                except (json.JSONDecodeError, ValueError):
                    continue
                content = (record.get("message") or {}).get("content")
                if not isinstance(content, list):
                    continue
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    if item.get("type") != "tool_use" or item.get("name") != "Bash":
                        continue
                    command = (item.get("input") or {}).get("command")
                    if command:
                        commands.append(command)
    return commands


def parse_argv(argv):
    opts = {"mode": None, "wrapper": None, "corpus_list": None, "count": DEFAULT_COUNT, "json": False}
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--engine":
            opts["mode"] = "engine"
        elif arg == "--wrapper":
            opts["mode"] = "wrapper"
            i += 1
            opts["wrapper"] = argv[i]
        elif arg == "--corpus-list":
            i += 1
            opts["corpus_list"] = argv[i]
        elif arg == "--count":
            i += 1
            opts["count"] = int(argv[i])
        elif arg == "--json":
            opts["json"] = True
        else:
            raise ValueError("unknown argument: %s" % arg)
        i += 1
    return opts


def resolve_corpus(opts):
    if opts["corpus_list"]:
        return read_corpus_list(opts["corpus_list"])
    return recent_transcripts(opts["count"])


def main(argv):
    try:
        opts = parse_argv(argv)
    except (ValueError, IndexError) as exc:
        print("rtk-coverage: %s" % exc, file=sys.stderr)
        return 2
    if opts["mode"] is None:
        print(
            "usage: rtk-coverage.py (--engine | --wrapper <path>) "
            "[--corpus-list <file> | --count N] [--json]",
            file=sys.stderr,
        )
        return 2
    paths = resolve_corpus(opts)
    commands = load_corpus(paths)
    if not commands:
        print("rtk-coverage: corpus produced no Bash commands", file=sys.stderr)
        return 1
    report = build_report(opts, paths, commands)
    if opts["json"]:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)
    return 0


def build_report(opts, paths, commands):
    return {"corpusFiles": len(paths), "bashCalls": len(commands)}


def print_report(report):
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
