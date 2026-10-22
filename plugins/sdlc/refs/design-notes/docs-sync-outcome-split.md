# Why post-QA docs sync splits WARN from STOP

Rationale for `refs/principal-engineer-playbook.md` Step 6.5 — not loaded at run time.

- A **docs-content** miss is recoverable by construction: the code branch is untouched and
  `/sdlc:docs sync <STORY-KEY>` (backed by the merged-commit source, `refs/docs-pipeline-postqa.md`
  §26) regenerates the docs after merge. Blocking a QA-clean PR over a docs regeneration hiccup would
  invert the story's value, so it is loud-but-non-blocking with a working recovery path.
- A **workspace-integrity** failure is not: a mutated/dirty primary checkout or a stray commit on the
  wrong branch outlives the run and breaks the next branch operation or the next epic child. The
  docs-content recovery argument does not reach it, so it stays a STOP, identical to Step 5.
- `Status: blocked` from the post-QA `knowledge-engineer` is therefore a docs-content WARNING — the
  one place an in-playbook agent `blocked` does not halt the run. The primary-checkout guard runs
  independently of the agent's returned `Status` and still STOPs.
