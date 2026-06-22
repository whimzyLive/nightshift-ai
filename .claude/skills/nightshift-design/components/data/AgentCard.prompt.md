A role in the AI software team — mono name, monogram avatar, and what it owns. Builds the "meet your team" grid of 11 agents.

```jsx
<AgentCard name="product-manager" owns="Vague idea → PRD with binary acceptance criteria" tone="accent" />
<AgentCard name="qa-engineer" owns="Always-on review → quality gate → AC verification → PR" tone="green" status="active" />
<AgentCard name="mobile-engineer" owns="Mobile apps" standby />
```

Auto-generates a monogram from the name (override with `glyph`). Tones: `accent · info · cyan · green`. `standby` dims conditional roles. `status` adds a colored status line.
