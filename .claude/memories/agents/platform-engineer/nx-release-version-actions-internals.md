---
id: nx-release-version-actions-internals
agent: [platform-engineer]
trigger: [custom VersionActions module, nx/release deep import, overriding abstract VersionActions member]
rule: 'For a custom `nx/release` `VersionActions` subclass, use the public `nx/release` barrel, not the `version-actions` deep path, which 404s at runtime despite matching `exports`.'
evidence: [NA-63]
uses: 0
status: active
---

## Why

`nx/release`'s package.json `exports` has a `./release/*` wildcard entry with no actual compiled
file behind `version-actions` — confirmed via `ts-node -e` runtime load, not just a type check.
`VersionActions.init(tree)` already resolves `manifestRootsToUpdate`/`validManifestFilenames` into
`this.manifestsToUpdate`, interpolating `{projectRoot}` for you. `Tree`/`ProjectGraph` types resolve
via `nx/src/*` (type-only, erased at runtime, no `MODULE_NOT_FOUND` risk). Under this repo's
`noImplicitOverride`, every abstract-member implementation needs the `override` keyword, and TS
structural typing allows a subclass method to declare fewer parameters than the abstract signature
requires. A `JSON.parse`/`stringify` round-trip risks reordering/reformatting `plugin.json`; a
regex like `/^(\s*"version"\s*:\s*)"[^"]*"/m` touches only the version value.
