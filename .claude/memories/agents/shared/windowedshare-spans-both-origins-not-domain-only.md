---
id: windowedshare-spans-both-origins-not-domain-only
agent: [ai-enablement-engineer, platform-engineer]
trigger: [read-bounding.py windowedShare, labeling a report field domain-agent reads, byOrigin orchestrator vs subagent split]
rule: read-bounding.py's windowedShare/topDecileShare/carveOutHitRate are computed over ALL reads (orchestrator+subagent) — don't label them "domain-agent only" without re-scoping to byOrigin.subagent.
evidence: [NA-90]
uses: 0
status: active
---

## Why

The NA-90 spec's own prose calls the baseline "domain-agent reads" (e.g. "1,380/5,292"), which
reads as subagent-origin-only. But `read-bounding.py`'s `windowedShare` (and `topDecileShare`,
`carveOutHitRate`) are computed over the full `sized` list — orchestrator reads (798) included
alongside subagent reads (5,287), 6,085 total. The report's `byOrigin` array carries read COUNTS
per origin but no per-origin windowed/carve-out breakdown, so there is currently no way to compute
a true subagent-only windowedShare from the JSON output alone. Anyone quoting these three fields in
a measurement block should either use the whole-corpus number as-is (matching the dispatch's own
pinned baseline) or explicitly flag that a domain-agent-only cut isn't available yet.
