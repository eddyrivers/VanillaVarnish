# VanillaVarnish project instructions

## Git workflow

- Repository: https://github.com/eddyrivers/VanillaVarnish
- The user authorizes committing and pushing directly to `main` whenever a major piece of work is complete. This is the default workflow for this repository; no additional confirmation is needed for those commits and pushes.
- Review the working tree, run checks appropriate to the change, and commit the completed work with a descriptive message before pushing to `origin main`.
- Preserve unrelated user changes. Never force-push, discard local work, or rewrite published history unless the user explicitly requests it.
- Include source, assets, documentation, tests, tools, and existing release ZIPs in version control. Keep dependency caches and temporary files ignored.
- Report the commit and push outcome. If authentication or network access blocks a push, preserve the local commit and explain what remains blocked.

## Validation and packaging

- The supported client is WoW Forever 1.60.x / Interface 16001. Do not claim other client compatibility without validation.
- Run `python tests/run.py --lua-runtime <directory-containing-lupa>` using Lupa's Lua 5.1 runtime for relevant code changes. Add `--blizzard-source <cached-native-nameplate-sources>` when those sources are available.
- Build release archives with `python tools/build_release.py`. Keep development instructions and Git metadata out of installed release packages.
