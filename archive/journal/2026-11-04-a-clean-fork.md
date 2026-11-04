# 2026-11-04: a clean fork, and issues first

**What happened.** Dominic: "it's very unclear if our version of the game works because of the changes or because of other changes." An audit agreed: `bin/lobster` couldn't be rebuilt from any commit, since it held code only in a stash, and Android patched the engine at build time. Now the fork's `game` branch is upstream plus one commit per fix, and the game passes its quick batch on it, with `perf:` level with the old binary (2.3 against 2.4 ms). The backlog and TODO moved to issues #18-#113. `lint.py` became `lint.sh`.

**Direction change.** The formatter went from a second grammar (arbiter signed off) to the compiler's own parser, because Dominic wanted no second grammar. Parsing needs names, so it takes whole programs.

**Funny moments.** The clean build's first Android run stopped dead, and it wasn't the fork: voxel units list their bodies with `scan_folder`, which can't list an APK. The game hadn't been run on Android since they arrived (#115). And `lint.sh --fix` reformatted Lobster's stock modules on its first run: a main file with no directory made "in this folder" match everything.

**Decisions.** D-210.

**Pictures.** `01-android-match-on-the-clean-fork.png`.

**Ideas parked.** Everything is in issues now, which was the point. Performance so far: `reports/performance.md`.
