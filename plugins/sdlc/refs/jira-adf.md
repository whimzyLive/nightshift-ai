# Jira ADF — Atlassian Document Format Reference

**Rule:** All Jira descriptions and comments written via `acli --description-file` MUST be ADF JSON. Plain markdown renders as raw symbols in Jira Cloud.

Save to a `.json` temp file under the session-scoped temp dir (never `/tmp` — outside permission scope):
```bash
dir=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/tmp-dir.sh)   # session-scoped ./.tmp/<key> (ET-58)
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
  "content": [ /* array of block nodes */ ]
}
```

---

## Block nodes

### paragraph
```json
{
  "type": "paragraph",
  "content": [
    { "type": "text", "text": "Plain text here." }
  ]
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
      "content": [
        { "type": "paragraph", "content": [{ "type": "text", "text": "Item one" }] }
      ]
    },
    {
      "type": "listItem",
      "content": [
        { "type": "paragraph", "content": [{ "type": "text", "text": "Item two" }] }
      ]
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
