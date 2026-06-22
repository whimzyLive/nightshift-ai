Code surface with filename header + copy button. Lightweight built-in tinting for shell prompts (`$`, `>`), comments, and Conventional Commit prefixes (`feat(scope):`).

```jsx
<CodeBlock filename=".claude/project/project-context.md" language="markdown" code={`...`} />
<CodeBlock language="bash" code={'$ /plugin install sdlc@nightshift'} showLineNumbers />
```

Props: `code`, `language`, `filename`, `showLineNumbers`, `copyable` (default true). No external highlighter — tinting is purpose-built for nightshift's command/commit samples.
