# Jira ADF — Atlassian Document Format Reference

**Rule:** All Jira descriptions and comments written via `acli --description-file` MUST be ADF JSON. Plain markdown renders as raw symbols in Jira Cloud.

Save to a `.json` temp file under the session-scoped temp dir (never `/tmp` — outside permission scope):

```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key>
desc=$(mktemp "$dir/acli-adf.XXXXXX.json")
trap 'rm -f "$desc"' EXIT
cat > "$desc" << 'EOF'
{ ... ADF JSON ... }
EOF
acli jira workitem create --description-file "$desc" ...
```

---

## Root structure

Every ADF document:

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    /* array of block nodes */
  ]
}
```

---

## Block nodes

### paragraph

```json
{
  "type": "paragraph",
  "content": [{ "type": "text", "text": "Plain text here." }]
}
```

### heading

```json
{
  "type": "heading",
  "attrs": { "level": 2 },
  "content": [{ "type": "text", "text": "Section Title" }]
}
```

`level`: 1–6. Use 2 for major sections, 3 for sub-sections.

### bulletList

```json
{
  "type": "bulletList",
  "content": [
    {
      "type": "listItem",
      "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "Item one" }] }]
    },
    {
      "type": "listItem",
      "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "Item two" }] }]
    }
  ]
}
```

### orderedList

Same as `bulletList` but `"type": "orderedList"`.

### taskList — for Acceptance Criteria checkboxes

```json
{
  "type": "taskList",
  "attrs": { "localId": "tl-1" },
  "content": [
    {
      "type": "taskItem",
      "attrs": { "localId": "ti-1", "state": "TODO" },
      "content": [{ "type": "text", "text": "Acceptance criterion text" }]
    },
    {
      "type": "taskItem",
      "attrs": { "localId": "ti-2", "state": "TODO" },
      "content": [{ "type": "text", "text": "Another criterion" }]
    }
  ]
}
```

`state`: `"TODO"` (unchecked) or `"DONE"` (checked). Always use `"TODO"` for new stories.
`localId` values must be unique within the document — use sequential strings (`tl-1`, `ti-1`, `ti-2`, …).

### codeBlock

```json
{
  "type": "codeBlock",
  "attrs": { "language": "typescript" },
  "content": [{ "type": "text", "text": "const x = 1;" }]
}
```

### rule (horizontal divider)

```json
{ "type": "rule" }
```

---

## Inline marks (apply to text nodes)

### bold

```json
{ "type": "text", "text": "Bold label", "marks": [{ "type": "strong" }] }
```

### italic

```json
{ "type": "text", "text": "Italic text", "marks": [{ "type": "em" }] }
```

### inline code

```json
{ "type": "text", "text": "someFunction()", "marks": [{ "type": "code" }] }
```

### link

```json
{
  "type": "text",
  "text": "Link label",
  "marks": [{ "type": "link", "attrs": { "href": "https://example.com" } }]
}
```

### Combined marks

```json
{ "type": "text", "text": "Bold+italic", "marks": [{ "type": "strong" }, { "type": "em" }] }
```

---

## Common patterns

### Bold label + plain value in same paragraph

```json
{
  "type": "paragraph",
  "content": [
    { "type": "text", "text": "Status: ", "marks": [{ "type": "strong" }] },
    { "type": "text", "text": "In Progress" }
  ]
}
```

### Mixed content paragraph (bold intro + body)

```json
{
  "type": "paragraph",
  "content": [
    { "type": "text", "text": "Key point: ", "marks": [{ "type": "strong" }] },
    { "type": "text", "text": "The service removes all manual orchestration." }
  ]
}
```

---

## Epic description template

Use for `/refine-feature` and any Epic create/update. Sections: Core Idea, Target Users, Key Value, Out of Scope, Open Questions.

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Core Idea" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "2–3 sentence description of what the feature/service does and why it exists." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Target Users" }]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "Role name — what they do with this feature" }] }]
        }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Key Value" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "What problem this solves and the measurable outcome." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Out of Scope (v1)" }]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "Explicit non-goal" }] }]
        }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Open Questions" }]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "Question — Owner: Name" }] }]
        }
      ]
    }
  ]
}
```

---

## Story description template

Use for `/refine-issue`, `/stories`, and any Story create/update. See `jira-story-template.md` for AC rules.

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "As a ", "marks": [{ "type": "strong" }] },
        { "type": "text", "text": "[specific role]" },
        { "type": "text", "text": "\nI want to ", "marks": [{ "type": "strong" }] },
        { "type": "text", "text": "[specific action]" },
        { "type": "text", "text": "\nSo that ", "marks": [{ "type": "strong" }] },
        { "type": "text", "text": "[business outcome]" }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Context" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "1–2 sentences explaining WHY this story exists." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Acceptance Criteria" }]
    },
    {
      "type": "taskList",
      "attrs": { "localId": "tl-1" },
      "content": [
        {
          "type": "taskItem",
          "attrs": { "localId": "ti-1", "state": "TODO" },
          "content": [{ "type": "text", "text": "Specific, testable criterion" }]
        },
        {
          "type": "taskItem",
          "attrs": { "localId": "ti-2", "state": "TODO" },
          "content": [{ "type": "text", "text": "Another criterion" }]
        },
        {
          "type": "taskItem",
          "attrs": { "localId": "ti-3", "state": "TODO" },
          "content": [{ "type": "text", "text": "Third criterion" }]
        }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Out of Scope" }]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "What this story does NOT cover" }] }]
        }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Dependencies" }]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "None" }] }]
        }
      ]
    }
  ]
}
```

---

## Bug description template

Use for `/refine-issue` and any **Bug** (`issuetype == Bug`) create/update. See
`jira-bug-template.md` for the 7-section structure and the required-vs-best-effort gate rules. A Bug
uses **headings + ordered/bullet lists — NOT the user-story `taskList`** (a bug has no Mike-Cohn ACs).
Render the 7 sections as: `heading` (level 3) per section title; `orderedList` for **Steps to
Reproduce**; `paragraph` for **Actual Result**, **Expected Result**, **Severity/Impact**, and
**Environment**; `bulletList` for **Attachments/Proof**. Best-effort sections absent (Environment,
Attachments/Proof) → render a `paragraph` / `listItem` with the text `not provided`.

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Environment" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "OS / device / browser or app version — or \"not provided\"" }]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Steps to Reproduce" }]
    },
    {
      "type": "orderedList",
      "content": [
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "First explicit action" }] }]
        },
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "Second explicit action" }] }]
        }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Actual Result" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Neutral statement of what currently happens." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Expected Result" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Clear, testable, neutral statement of what should happen." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Severity / Impact" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Importance level + affected audience." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 3 },
      "content": [{ "type": "text", "text": "Attachments / Proof" }]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "Screenshot / recording / error log — or \"not provided\"" }] }]
        }
      ]
    }
  ]
}
```

The **Summary / Title** (section 1) is the Jira issue summary field, not part of the description ADF —
set it via `--summary` (e.g. `[iOS] Cart checkout button unresponsive`).

---

## Minimal sub-task description

When refining a story that has child sub-tasks, the parent story's own description folds each sub-task's scope into its **existing Acceptance Criteria** `taskList` (one extra `taskItem` per sub-task, derived from the sub-task summary) — there is **no separate "Sub-tasks" section, heading, or second `taskList`**. Re-use the single AC `taskList` (`localId` scheme `tl-1` / `ti-*`).

Each child **sub-task** then gets its own minimal description — purpose only, **no story template** (no Mike Cohn line, no AC list, no Out of Scope / Dependencies headings):

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "One sentence stating the sub-task's purpose, derived from its summary (do not invent acceptance criteria)." }]
    },
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "Part of ", "marks": [{ "type": "strong" }] },
        { "type": "text", "text": "ED-456" }
      ]
    }
  ]
}
```

Replace `ED-456` with the parent story key. If the sub-task summary is empty, fall back to a generic one-line purpose that references the parent.

---

## Comment template

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Comment text here." }]
    }
  ]
}
```

The comment subcommand is `acli jira workitem comment create --key <KEY>` (there is **no** `comment add` subcommand — it errors `unknown command`). It accepts both `--body "<text>"` and `--body-file <file>`. For multi-line/ADF bodies use `--body-file` (`.md` plain text or `.json` ADF); single-paragraph plain text via `--body` is fine (ADF not required).
