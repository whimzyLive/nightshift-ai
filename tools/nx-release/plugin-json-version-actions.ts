import { VersionActions } from 'nx/release';

import type { Tree } from 'nx/src/generators/tree';

/**
 * Matches a top-level `"version": "x.y.z"` field so it can be rewritten in
 * place without touching any other key, ordering, or formatting in the file.
 */
const VERSION_FIELD_PATTERN = /^(\s*"version"\s*:\s*)"[^"]*"/m;

/**
 * Custom Nx `VersionActions` for Claude plugins.
 *
 * `nx release`'s default version actions read/write `package.json`, but a
 * plugin's version lives in `.claude-plugin/plugin.json` instead — plugins
 * are Claude marketplace artifacts, not npm packages. This module points
 * `nx release` at that manifest and treats the `dependencies` array there
 * (Claude marketplace refs, e.g. `{ name, marketplace }`) as opaque — never
 * as versioned Nx dependencies.
 */
export default class PluginJsonVersionActions extends VersionActions {
  override validManifestFilenames: string[] = ['plugin.json'];

  override async readCurrentVersionFromSourceManifest(
    tree: Tree,
  ): Promise<{ currentVersion: string; manifestPath: string } | null> {
    const manifestPath = this.manifestsToUpdate[0]?.manifestPath;
    if (!manifestPath) {
      return null;
    }
    const contents = tree.read(manifestPath, 'utf-8');
    if (!contents) {
      return null;
    }
    const { version } = JSON.parse(contents) as { version?: string };
    if (!version) {
      return null;
    }
    return { currentVersion: version, manifestPath };
  }

  override async readCurrentVersionFromRegistry(): Promise<null> {
    // Plugins are not published to any package registry.
    return null;
  }

  override async readCurrentVersionOfDependency(): Promise<{
    currentVersion: string | null;
    dependencyCollection: string | null;
  }> {
    // plugin.json's `dependencies` array holds Claude marketplace refs, not
    // semver-versioned Nx dependencies — nothing to resolve here.
    return { currentVersion: null, dependencyCollection: null };
  }

  override async updateProjectVersion(
    tree: Tree,
    newVersion: string,
  ): Promise<string[]> {
    const messages: string[] = [];
    for (const { manifestPath } of this.manifestsToUpdate) {
      const contents = tree.read(manifestPath, 'utf-8');
      if (!contents || !VERSION_FIELD_PATTERN.test(contents)) {
        continue;
      }
      tree.write(
        manifestPath,
        contents.replace(VERSION_FIELD_PATTERN, `$1"${newVersion}"`),
      );
      messages.push(`Updated ${manifestPath} to v${newVersion}`);
    }
    return messages;
  }

  override async updateProjectDependencies(): Promise<string[]> {
    // Never rewrite the marketplace `dependencies` array — those are not
    // versioned Nx dependencies.
    return [];
  }
}
