# Releases (Persian Tuner fork)

This fork publishes a new release **automatically after every PR merged into the
`persian-tuner` branch**. Each release contains ready-to-install packages for
all supported desktop platforms, just like the upstream
[MuseScore Studio releases](https://github.com/musescore/MuseScore/releases).

## Versioning (step-by-step)

The version is bumped automatically on every merge, following this ladder:

```
1.0.1 -> 1.0.2 -> 1.0.3 -> ... -> 1.0.9 -> 1.0.10 -> 1.1.0 -> 1.1.1 -> ...
```

* Patch number increases by 1 per merge, up to `X.Y.10`.
* After `X.Y.10` the minor number increases and the patch resets (`1.0.10 -> 1.1.0`).
* The new version is written to [`version.cmake`](version.cmake), committed to
  the branch and tagged, so tags and app versions always stay in sync.

## What happens on each merge

The workflow [`.github/workflows/release_on_merge.yml`](.github/workflows/release_on_merge.yml)
runs on every push to `persian-tuner`:

1. **Bump** — computes the next version from the latest `X.Y.Z` tag, updates
   `version.cmake`, and commits it (the commit contains `[skip release]` and is
   pushed with the `GITHUB_TOKEN`, so it never triggers the workflow again).
2. **Build** — builds stable installers for all platforms (reusing the
   upstream CI pipeline):
   * Linux: `MuseScore-Studio-<version>.<build>-x86_64.AppImage`
     and `-aarch64.AppImage` (+ `.zsync`)
   * macOS: `MuseScore-Studio-<version>.<build>.dmg`
   * Windows: `MuseScore-Studio-<version>.<build>-x86_64.msi`
     and `-x86_64.paf.exe` (PortableApps)
   * plus `checksums.sha256.txt`
3. **Release** — creates the git tag (e.g. `1.0.1`) and publishes a GitHub
   Release with those installers attached and auto-generated release notes.

A full build takes a few hours (Windows, macOS and Linux run in parallel).

## Manual release

1. Go to **Actions → Release: Persian Tuner → Run workflow**.
2. Leave *version* empty to auto-bump, or type an exact version
   (e.g. `1.0.0`) to (re)build that version.
3. Run the workflow.

If the tag/release already exists, the workflow keeps the tag and uploads the
newly built installers to the existing release.

## Skipping a release

To push to `persian-tuner` **without** creating a release (e.g. a version-bump
or documentation-only commit), include `[skip release]` in the commit message.
