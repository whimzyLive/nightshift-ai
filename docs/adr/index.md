# ADR Index

Deterministically generated from the frontmatter of every ADR in this directory. Do not
hand-edit — fix the source ADR's frontmatter and regenerate instead.

## ai-enablement-engineer

- [0001. Split every founder-confirmation gate across two stateless subagent dispatches](0001-two-phase-dispatch-founder-confirmation-gate.md) — accepted
- [0002. Verify markdown edits under plugins/sdlc/\*\* with an in-tree, two-pass Prettier diff — never trust a pre-commit dry run](0002-in-tree-prettier-idempotency-verification.md) — accepted
- [0003. Shared cross-file contracts get exactly one canonical statement, with every other site reduced to a pointer](0003-one-source-of-truth-with-pointers.md) — accepted
- [0005. Never operate from the shared/primary checkout path inside a dispatched worktree; free branch locks via ff-only merge](0005-worktree-isolation-discipline.md) — accepted
- [0006. An explicit dispatch-prompt push instruction overrides the standing commit-only handoff default](0006-dispatch-prompt-push-override.md) — accepted

## knowledge-engineer

- [0001. Split every founder-confirmation gate across two stateless subagent dispatches](0001-two-phase-dispatch-founder-confirmation-gate.md) — accepted

## platform-engineer

- [0005. Never operate from the shared/primary checkout path inside a dispatched worktree; free branch locks via ff-only merge](0005-worktree-isolation-discipline.md) — accepted
- [0006. An explicit dispatch-prompt push instruction overrides the standing commit-only handoff default](0006-dispatch-prompt-push-override.md) — accepted

## qa-engineer

- [0002. Verify markdown edits under plugins/sdlc/\*\* with an in-tree, two-pass Prettier diff — never trust a pre-commit dry run](0002-in-tree-prettier-idempotency-verification.md) — accepted
- [0004. Reduced-motion gates must register complementary matchMedia conditions and resolve post-mount](0004-reduced-motion-matchmedia-gating.md) — accepted
- [0007. Every public-route Payload/CMS read gets a try/catch-to-defaults fallback and export const dynamic = 'force-dynamic'](0007-public-route-cms-read-fallback.md) — accepted

## web-engineer

- [0004. Reduced-motion gates must register complementary matchMedia conditions and resolve post-mount](0004-reduced-motion-matchmedia-gating.md) — accepted
- [0005. Never operate from the shared/primary checkout path inside a dispatched worktree; free branch locks via ff-only merge](0005-worktree-isolation-discipline.md) — accepted
- [0007. Every public-route Payload/CMS read gets a try/catch-to-defaults fallback and export const dynamic = 'force-dynamic'](0007-public-route-cms-read-fallback.md) — accepted
