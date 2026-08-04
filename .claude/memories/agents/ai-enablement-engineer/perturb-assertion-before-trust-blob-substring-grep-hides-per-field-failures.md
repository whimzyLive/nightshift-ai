---
id: perturb-assertion-before-trust-blob-substring-grep-hides-per-field-failures
agent: [ai-enablement-engineer]
trigger: [writing a new CI or shell assertion, reviewing a falsifiability register before shipping, a grep-for-a-token or substring check over a multi-field JSON blob or multi-item output]
rule: An assertion must be perturbed before it is trusted; a substring/grep check over a whole blob is the specific shape that fails silently — extract and compare the individual field instead.
evidence: [NA-87, NA-91, NA-92]
uses: 0
status: active
---

## Why

This shape has now been caught four times on epic NA-76, always the same generalisation: an
assertion nobody perturbed before trusting it.

- **NA-87 tier-1 gate**: reference artifacts were generated to match the thing under test
  positionally, so the gate could not fail — it was checking that a file matched itself.
- **NA-91 F-6** ([[verification-grep-fixed-string-and-avoid-naming-marker-in-prose]]): the grepped
  token also appeared in the block's own explanatory prose, so deleting the row it was meant to
  catch left the assertion passing — the token count never dropped to zero.
- **NA-92 Phase 1**: four contract keys (`Stray files:`, `Commands:`, `Evidence:`, `Unmet:`) each
  occurred twice in the same file — once in the actual contract line, once in surrounding prose
  restating it — which would have made those `grep -qF` presence assertions unfalsifiable: no
  edit that deleted only the contract line would have dropped the count to zero.
- **NA-92 Phase 2 F-11**: `work-placement.test.sh`'s original assertion checked `subagentShare`
  via a whole-blob substring match (`"subagentShare": 1.0` present _anywhere_ in the JSON). Under
  the F-11 perturbation (swapping the corpus's recursive `rglob` for a non-recursive `glob`), two
  of the three units (G1, G2) still resolved to 1.0 via the shallower pattern — only G3's fixture
  signature lived exclusively in the T3 tier — so the substring check stayed green, masking the
  one unit that actually regressed. [[guard-proves-mechanics-not-prose-accuracy]] is the same
  family: a check scoped to a narrow structural slice (frontmatter only, or "the string appears
  somewhere") proves that slice and nothing about the rest.

The common failure is not "the assertion is wrong" — every one of these four passed on first
write, against a correct-looking implementation. It is that nobody ran the assertion against a
known-bad input before shipping it as a gate. A substring/grep-over-blob check is the specific
shape most likely to hide this, because it can go green from _any_ matching occurrence rather
than the one the author intended — extracting and comparing the individual field (a JSON key via
`python3 -c "import json,sys; ..."`, a section via `awk`-bounded extraction, not `grep -c` on the
whole file) removes that ambiguity. Before trusting any new assertion, apply the perturbation
that should flip it to FAIL, observe the FAIL, then restore and observe the PASS — the same
discipline this story's own falsifiability register (`docs/superpowers/plans/NA-92-measurements/byte-accounting.txt`)
applies to itself.
