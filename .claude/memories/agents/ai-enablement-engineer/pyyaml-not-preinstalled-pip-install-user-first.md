---
id: pyyaml-not-preinstalled-pip-install-user-first
agent: [ai-enablement-engineer]
trigger: [python3 -c "import yaml" ModuleNotFoundError, YAML-parse verification gate]
rule: This repo's runner has no `pyyaml` preinstalled.
evidence: [NA-15]
uses: 0
status: active
---
