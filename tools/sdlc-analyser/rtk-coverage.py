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


EXCLUDE = ("tsc", "prettier", "nx", "eslint", "lint", "vitest", "jest", "pytest")
RUNNER_PREFIXES = ("pnpm", "npm", "yarn", "bun", "npx", "bunx", "pnpx", "exec", "dlx", "run", "x")
SEGMENT_SEPARATORS = ("&&", "||", ";", "|")

_ORACLE_CACHE = {}


def rtk_rewrites(line):
    if line not in _ORACLE_CACHE:
        try:
            result = subprocess.run(
                ["rtk", "hook", "check", "--", line],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            _ORACLE_CACHE[line] = result.returncode == 0
        except OSError:
            _ORACLE_CACHE[line] = False
    return _ORACLE_CACHE[line]


def split_segments(line):
    segments = [line]
    for separator in SEGMENT_SEPARATORS:
        nxt = []
        for segment in segments:
            nxt.extend(segment.split(separator))
        segments = nxt
    return segments


def resolve_head(segment):
    words = segment.split()
    while words:
        word = words[0]
        if "=" in word or word in RUNNER_PREFIXES:
            words = words[1:]
            continue
        break
    if not words:
        return ""
    return os.path.basename(words[0]).lower()


def line_is_excluded(line):
    return any(resolve_head(s) in EXCLUDE for s in split_segments(line))


def build_report(opts, paths, commands):
    multi_line = 0
    achievable_raw = 0
    guard_heredoc = 0
    guard_exclude = 0
    rewrites = 0

    for command in commands:
        lines = command.split("\n")
        if len(lines) > 1:
            multi_line += 1
        has_heredoc = "<<" in command
        for line in lines:
            if not line.strip() or not rtk_rewrites(line):
                continue
            achievable_raw += 1
            if has_heredoc:
                guard_heredoc += 1
            elif line_is_excluded(line):
                guard_exclude += 1
        rewrites += count_rewrites(opts, command, lines)

    permitted = achievable_raw - guard_heredoc - guard_exclude
    lost_raw = achievable_raw - rewrites
    lost_permitted = permitted - rewrites
    return {
        "mode": opts["mode"],
        "wrapper": opts["wrapper"],
        "corpusFiles": len(paths),
        "bashCalls": len(commands),
        "multiLine": multi_line,
        "achievableRaw": achievable_raw,
        "guardHeredoc": guard_heredoc,
        "guardExclude": guard_exclude,
        "achievablePermitted": permitted,
        "rewrites": rewrites,
        "lostRaw": lost_raw,
        "lostRawPct": pct(lost_raw, achievable_raw),
        "lostPermitted": lost_permitted,
        "lostPermittedPct": pct(lost_permitted, permitted),
    }


def pct(part, whole):
    return round(100.0 * part / whole, 1) if whole else 0.0


def wrapper_rewrites(wrapper_path, command):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    try:
        result = subprocess.run(
            ["bash", wrapper_path],
            input=payload.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError:
        return 0
    stdout = result.stdout.decode("utf-8", "ignore").strip()
    if not stdout:
        return 0
    try:
        updated = json.loads(stdout)["hookSpecificOutput"]["updatedInput"]["command"]
    except (ValueError, KeyError, TypeError):
        return 0
    before = command.split("\n")
    after = updated.split("\n")
    if len(before) != len(after):
        return 0
    return sum(1 for a, b in zip(before, after) if a != b)


def count_rewrites(opts, command, lines):
    if opts["mode"] == "wrapper":
        return wrapper_rewrites(opts["wrapper"], command)
    if "<<" in command:
        return 0
    first = lines[0]
    if not first.strip() or line_is_excluded(first) or not rtk_rewrites(first):
        return 0
    return 1


def print_report(report):
    print("\n### rtk-coverage — %s" % report["mode"])
    if report["wrapper"]:
        print("wrapper: %s" % report["wrapper"])
    print(
        "corpus files %d  bash calls %d  multi-line %d (%.1f%%)"
        % (
            report["corpusFiles"],
            report["bashCalls"],
            report["multiLine"],
            100.0 * report["multiLine"] / max(report["bashCalls"], 1),
        )
    )
    print("achievable (raw)      %d" % report["achievableRaw"])
    print("  guard: heredoc      -%d" % report["guardHeredoc"])
    print("  guard: EXCLUDE      -%d" % report["guardExclude"])
    print("achievable-permitted  %d" % report["achievablePermitted"])
    print(
        "rewrites %d   lost-vs-raw %d (%.1f%%)   lost-vs-permitted %d (%.1f%%)"
        % (
            report["rewrites"],
            report["lostRaw"],
            report["lostRawPct"],
            report["lostPermitted"],
            report["lostPermittedPct"],
        )
    )
    print(
        "\nNOTE (NA-88 D11, self-confirming): this instrument and the wrapper it scores were "
        "authored by the same story. A pass proves only that the wrapper does what its own "
        "author designed -- it does not prove rewritten commands still execute correctly or "
        "that any token was saved."
    )
    print(
        "Falsifiability: the same corpus through --engine (unwrapped) returns ~72-79% lost; "
        "through --wrapper it returns near-0%. A gate returning the same number either way "
        "would be evidence about nothing."
    )


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
