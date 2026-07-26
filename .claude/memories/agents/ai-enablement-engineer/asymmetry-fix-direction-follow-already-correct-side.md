---
id: asymmetry-fix-direction-follow-already-correct-side
agent: [ai-enablement-engineer]
trigger: [skill loaded unconditionally but Skills-loaded return listed conditionally, fixing a load/list asymmetry]
rule: When a review finds a load/list asymmetry (a skill loaded unconditionally but the return contract lists it conditionally, or vice versa), check which side already states a correct, well-reasoned.
evidence: [NA-52]
uses: 0
status: active
---

## Why

The fix was to make the load conditional (only when actually needed) to match the already-correct,
well-motivated conditional return line, rather than loosening the return to unconditional — the
return condition was already correct (a phase genuinely never drafts in some cases), so loosening it
would have been the wrong direction.
