# Contributing

VanillaVarnish supports **WoW Forever 1.60.x / Interface 16001**. Keep changes focused, preserve per-character preferences, and avoid competing with Blizzard's secure UI or loaded standalone addons. All addon slash commands belong under `/vv`.

## Run checks

Use Python 3.11 or newer and Lupa's Lua 5.1 runtime:

```sh
python -m pip install --target .test-deps/lua-runtime lupa==2.8
python tests/run.py --lua-runtime .test-deps/lua-runtime
python -m unittest discover -s tests -p "test_*.py"
python tools/build_release.py
```

Optional native source snapshots stay in `.test-deps` or another local cache. Pass `--blizzard-source <directory>` containing the native nameplate files expected by `tests/run.py`. For tooltip checks, pass `--tooltip-source <directory>` containing `shared.lua`, `tooltip.lua`, and optionally `container.lua` from the [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns).

Before release, check changed features in game after `/reload`: combat transitions, settings and saved preferences, native nameplate styles, secure quest items, and party targeting. For threat colors, check tanks holding and losing aggro, damage/healer roles, tank forms/stances, tapped or dead enemies, and the feature switch. Mocks cannot validate taint, rendered artwork, or cursor behavior.

For party range fading, cross the friendly spell's range boundary, clear the spell, and change party-frame styles. Verify portraits and buffs fade together while health, mana, and debuffs stay unchanged, including in combat. For the player cast bar, enable `/vv nameplates cast on`, cast and channel while targeting a casting enemy, interrupt a cast, change targets, and try the native nameplate styles/sizes. Check X/Y/width, native bar height, the menu preview, offscreen targets, and both feature/master switches. The native-source suite exercises the real casting mixin across all styles and sizes; it does not replace a rendered in-game check.

## Publish a release

GitHub Actions tests and builds pushes to `main`, pull requests, and version tags. Only a pushed version tag publishes to [CurseForge](https://www.curseforge.com/wow/addons/vanilla-varnish). Manual workflow runs validate and package without publishing.

Maintainer setup: store a CurseForge author API token as the repository Actions secret `CF_API_TOKEN`. The project ID is declared in `VanillaVarnish.toc`; publishing is restricted to Forever `1.60.1` and fails if CurseForge has no exact matching game-version entry. Keep CurseForge's native automatic packager disabled to avoid duplicate uploads. Credentials belong in GitHub secrets, never source files or documentation.

1. Update the TOC version and add concise release notes to `CHANGELOG.md`.
2. Run the checks and build with `python tools/build_release.py`.
3. Commit the source, docs, and generated `dist/VanillaVarnish-<version>.zip`, then push.
4. Create and push the matching tag, for example `git tag v1.0.19` and `git push origin v1.0.19`.
5. Check the Actions run and the CurseForge file status. New projects and uploads may need moderation before becoming visible in the app.

The workflow verifies that the tag matches the TOC and that the committed ZIP matches the freshly built package. Alpha or beta suffixes in the version select the corresponding CurseForge release type; ordinary versions publish as Release.

Release archives contain runtime code, assets, the user guide, release notes, and licenses. Tests, automation, branding, local maintainer instructions, caches, and Git metadata stay out of installed packages. Retain existing archives for users who need an earlier release.

Write commit messages and documentation for the public reader: describe the behavior and its purpose, keep the useful details, and leave the debugging diary behind. A little varnish goes a long way.
