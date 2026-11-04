# Lobster PRs: what, why, and whose fault

Written 2026-11-04. Local working notes, not committed. Tick the boxes or write on it as you go.

**Pushed 2026-11-04:** #468 (pool only, reply posted), #469 (SDL3 only), new drafts #472 (touch position)
and #473 (`ReadTexture`). All timings are from this Mac, on macOS.

## The short version

| # | Change | Are we using Lobster wrong? | My recommendation |
|---|---|---|---|
| 1 | SDL3 Android template (#469) | No, the template is out of date | Push first |
| 2 | Buffer pool (#468) | No, Lobster's bug on macOS | Push second |
| 3 | `gl.text_list` (#471) | No, but **the game doesn't call it, and the pool makes it unnecessary here** | Pause it, probably close |
| 4 | Touch position (new draft) | No, Lobster's bug | Find a repro, then ready it |
| 5 | Touch delay and lost taps | **Probably yes, our game code** | No Lobster PR, fix the game |
| 6 | `ReadTexture` on GLES (new draft) | No, a missing feature | Test it, then ready it |
| 7 | `SaveTexture` on GLES | No, a missing feature | Later, optional |
| 8 | `gl.draw_mesh` (to split from #468) | **Partly: we caused the worst of it** | Answer Wouter's question first |
| 9 | `gl.buffers_made` (to split from #468) | No, it's our test tool | Keep it local |
| 10 | Formatter (#466, #460) | Not about usage | Neither merged, separate C++ tool |
| 11 | LSP (#459) | Not about usage | Waiting on review, too big |
| 12 | `gl.window_focused`, frame sleep | No | You said don't PR |

**Two things changed while writing this:**

- **#471:** the 27.6 ms you quoted on the PR was measured without the pool. With the pool, plain
  `gl.text` is already as fast as `gl.text_list` (item 3). That comment may need correcting.
- **Touch switch:** I suggested a program-wide `gl.touch_delay` switch. I now think we don't need
  it, because the game ignores a value Lobster already gives it (item 5).

## 1. SDL3 Android template (#469)

- **What:** SDL 3.4 Java files, Gradle and the Android plugin, SDK 35, min 21, CI on JDK 17, and
  `--cpp` naming the entry `SDL_main` on Android.
- **Why:** Lobster's engine is on SDL3, but its Android template still had old Java and old tooling.
- **Right or wrong?** Not us. Our build works around it: `src/android/build.sh` copies its own SDL
  Java and rewrites `main` to `SDL_main` with `sed`. We could drop some of that once this lands.
- **Evidence:** `samples/dragtest.lobster` with `--cpp`, with only this change, starts on the
  Android 16 emulator and drags draw lines. Built with NDK 29, the plugin prefers 28.
- **State:** committed locally (`a46935b5`), new title and description ready.
- **Not tested:** a real phone. The old description claimed "a full game on a phone", and I've
  taken that out because I can't back it up.

### Wouter's points on #469

| He said | Where it goes |
|---|---|
| Removing the touch delay breaks `gl.hit` plus a press, and existing games rely on it | Delay restored, see item 5 |
| Keep the `updatedragpos` fix | Item 4 |
| `ReadTexture`: check the framebuffer, return nullptr if incomplete | Done, item 6 |
| `SaveTexture` could reuse `ReadTexture` (not blocking) | Left out, item 7 |
| The description wrongly says CI doesn't build Android | Fixed in the new text |

- [x] Push and update #469

## 2. Buffer pool (#468)

- **What:** `RenderArraySlow` draws from buffers kept per vertex format and reused each frame.
- **Why:** on macOS, deleting a GL buffer waits for the GPU, and Lobster made and deleted buffers
  on every immediate draw.
- **Right or wrong?** Lobster's bug. `gl.text` carries no warning and is normal use, and it's slow
  too. `gl.polygon` and `gl.rect_tc_col` do warn in their docs that they're slow.
- **Wouter's question:** does it reuse enough, given it ignores size?

| Test | No pool | Pool by format | Pool by size | By format, limit 256 |
|---|---|---|---|---|
| The game, about 168 draws a frame (work per frame) | 27.6 to 30.2 ms | 0.9 to 2.4 ms | 1.4 to 2.3 ms | 1.6 to 1.9 ms |
| Worst case, 1,000 draws, every size changing (whole frame) | 132 to 135 ms | 3.5 ms | 3.5 to 3.6 ms | 3.3 to 3.5 ms |

The limit 256 runs in the game aren't a clean comparison: two of the three rounds had 151 draws a
frame, not 168, and the limit was never reached. The worst-case row is the real test of the limit.

So size doesn't matter and the limit costs nothing. Wouter's review points on freeing the pool at
shutdown and on it only growing are both fixed, and `SetAttribs` is moved unchanged.

**Pixel check, done on this exact branch:** 1,200 mixed `gl.text`, `gl.polygon` and `gl.rect_tc_col`
draws in one frame, so the pool wraps past the limit 4 times. 4 frames, 1 MB of pixels each, the same
hash with and without the pool. Unit tests pass (3,510 checks). The diff was read hunk by hunk.

**Limits of this evidence:** the timings are macOS only and came from a test build, not this exact
branch. There's no automated test in the PR, because the old one needed `gl.buffers_made`.

**New title:** Draw immediate geometry from pooled buffers

**New description:**

> On macOS, deleting a GL buffer waits for the GPU. `RenderArraySlow` (behind `gl.text`, `gl.polygon`,
> `gl.rect_tc_col` and others) made and deleted buffers on every call, so frames with many of these
> mostly waited. It now draws from buffers pooled per vertex format and reused each frame, up to 256
> per format, then wrapping around. They're freed in `OpenGLCleanup`.
>
> ```lobster
> // on macOS: each line costs a GPU sync, so this frame takes many ms
> while gl.frame():
>     for(500) i: gl.text("hello {i}")
> ```
>
> **Tests:** no automated test. 1,200 mixed draws in one frame, past the limit, give identical pixels
> with and without the pool, on macOS. The unit tests pass. Not measured on Linux or Windows.

**Reply to Wouter:**

> You asked whether reuse is good enough, so I measured it on macOS. In our game (about 168 draws a
> frame, 20 s, 3 runs) work per frame goes from about 29 ms to about 2 ms, and draws after warm-up
> reuse a buffer every time, because a game draws much the same things in the same order each frame.
> About 99% have the same vertex size as that buffer's last draw. The worst case, 1,000 draws a frame
> with every buffer changing size every frame, goes from 133 ms to 3.5 ms. Pooling by size as well made
> no measurable difference (3.6 ms), so format alone stays. Limiting the pool to 256 per format,
> wrapping around, was no slower (3.4 ms), and pixels are identical past the limit. I haven't measured
> Linux or Windows.
>
> I've taken out the drive-by changes: `SetAttribs` is moved unchanged. `gl.draw_mesh` and
> `gl.buffers_made` are out of this PR, and I'll only bring back what still proves necessary.

- [x] Push, new title and description, post the reply

## 3. `gl.text_list` (#471)

- **What:** draws a list of strings in one call.
- **Why:** many `gl.text` calls were slow. Wouter suggested it as his *second* idea. His first was
  that the slowness is mostly `RenderArraySlow` making buffers. He was right:

| 200 labels, ms a frame, 3 runs | Result |
|---|---|
| `gl.text` each, no pool | 25.9, 25.3, 32.7 |
| `gl.text_list`, no pool | 1.00, 1.02, 1.24 |
| `gl.text` each, **with the pool** | 1.23, 1.20, 1.05 |

- **Right or wrong?** We're not misusing anything, but we may be solving a problem we no longer
  have. **The game doesn't call `gl.text_list`.** It has its own text atlas
  (`src/game/text_cache.lobster`), with only 5 `gl.text` calls left in the whole game, 2 of them in
  `src/view/bake_cache.lobster`.
- **For keeping it:** it's still 1 draw call instead of 200, which may matter on a phone GPU, and
  I haven't measured that.
- **State:** pushed, CI passes. Wouter has an open comment asking to `reserve` the vectors.

**Recommendation:** land the pool, then pause #471 and tell Wouter the pool alone gets there on
macOS. Only bring it back if a phone measurement shows draw calls matter.

- [x] Paused: #471 is a draft while #468 is open. Close it, or keep it if a phone measurement shows draw calls matter
- [x] Corrected the 27.6 ms in a new comment on #471

## 4. Touch position (draft #472)

- **What:** a finger's position comes from its own event, and finger-up updates it too.
- **Why:** `updatedragpos` looks the finger up in SDL's list, and a finger that has already lifted
  isn't there. It falls through to finger 0 without updating, which gives the click at (0, 0). The
  list is also never freed.
- **Right or wrong?** Lobster's bug. Wouter agrees in his review.
- **Evidence: none yet that works.** My emulator drag test proved nothing: line ends vary from run
  to run, with or without the fix.
- **Next:** a tap only hits this when its press and lift land in one frame, so a sample that sleeps
  about 200 ms each frame should show it on demand. Compare the printed positions.

- [ ] Write the repro, then mark the draft ready

## 5. Touch delay and lost taps (no PR planned)

- **What it is:** on touch, `GetKS` reports buttons one frame late so that `gl.hit` works. A tap
  pressed and lifted within one frame never reports "went down".
- **Why it bit us:** `src/game/touch.lobster` starts a touch on `one == 1`, the first value from
  `gl.button`. Our Android build patches the delay out (`src/android/lobster_android.py`).
- **Right or wrong? Probably us.** `gl.button` returns two values, and its docs say both can happen
  in one frame. From reading the code, that tap comes back on the next frame as down 0, up 1. The
  game only reads the first value, so it never sees it.
- **Fix to try:** treat `up == 1` with no touch in progress as a tap, then remove the patch. It
  needs item 4's position fix to tap the right place.
- **What we'd give up:** every touch arrives one frame later. Wouter's own `FIXME` calls this lag.
- **Not tested:** this is from reading the code only.

- [ ] Try it in the game with the sleeping sample from item 4

## 6. `ReadTexture` on GLES (draft #473)

- **What:** reads a texture through a framebuffer on GLES, and returns nullptr for depth and integer
  textures.
- **Why:** GLES has no `glGetTexImage`, so `gl.read_texture` always returned nil.
- **Right or wrong?** Not us, it's a missing feature. The game calls it at `src/game/panel.lobster:480`
  and `src/view/voxel_mesh.lobster:99`, and both quietly fall back to an empty string on nil.
- **State:** the framebuffer check hasn't been run in this form. Our game's patch has the same read
  without the check.

- [ ] Run it on the emulator, then mark the draft ready

## 7. `SaveTexture` on GLES (not started)

- **What:** make `gl.save_texture` work on GLES using `ReadTexture`. Wouter's non-blocking idea.
- **Why:** the game has its own slower PNG fallback for this (`src/game/voxel_units.lobster:268`).
- **Right or wrong?** Not us.

- [ ] Decide: do it after item 6, or skip

## 8. `gl.draw_mesh` (to split from #468)

- **What:** draws `gl.new_mesh`'s arguments from the pool without making a mesh.
- **Why:** to draw shapes that change every frame, such as batches of coloured or textured quads.
- **Right or wrong? Partly us.** D-188 says the UI made about 1,500 buffers a frame, 13.7 ms of work,
  because we called `gl.new_mesh` and `gl.render_mesh` every frame. Meshes are for things that last,
  so that was our mistake. The gap behind it is real, though: `gl.polygon` takes positions only, and
  `gl.rect_tc_col` draws one quad.
- **Wouter's questions, still open:** "Is it needed at all, now that `gl.polygon` and friends are
  cheap?", and could it have a better name, such as `gl.draw_triangles`. Its errors also say `newmesh:`.
- **Evidence needed:** the game has 17 calls. Most need per-vertex colour or texture coordinates; a
  couple are positions only. Measure the batches (`game/pack.lobster`) drawn as separate pooled
  `gl.rect_tc_col` calls against `gl.draw_mesh`. If it's close, we may not need this PR.
- **State:** no branch yet. The old code is on `gl-pooled-buffers`. The game depends on it.

- [ ] Measure, then decide whether to PR it

## 9. `gl.buffers_made` (to split from #468)

- **What:** a counter of GPU buffers made.
- **Why:** only `src/game/perf.lobster` uses it, to fail the check if a frame makes buffers.
- **Right or wrong?** Nothing wrong, but it's our test tool. Wouter would rather have one stats call
  than one builtin per counter.

- [ ] Keep it in our local Lobster (my suggestion), or propose a stats call

## 10. Formatter (#466, closed #460)

- **Decision (Dominic, 2026-11-04):** neither gets merged. Do it properly, in C++, as other languages
  do, without loading the compiler with formatter code.
- **Right or wrong?** Not about usage.
- **Why Lobster's parser can't be the library as it stands:** `Parser` needs a `SymbolTable` and a
  `NativeRegistry`, makes 135 `st.` references, follows imports and rewrites `for` loops while it
  parses. The tree has only line numbers, no columns. The lexer drops comments.
- **Proposed design, as clang-format does it:** a separate `lobsterfmt` program that reuses `lex.h`,
  with its own small structure pass and layout rules. The lexer gains only a way to report comments
  and token offsets. `#466`'s layout rules and tests carry over as the starting point.
- **Safety check, as Black does it:** compile before and after and compare, in tests rather than in
  the compiler. Line numbers in the output may complicate this, not checked yet.
- **Not checked yet:** how much of `lex.h` works outside the compiler, and how much work this is.

- **Done (2026-11-04), local branch `lobsterfmt-cpp`, not pushed; an independent arbiter agent signed it off:**
  `dev/lobsterfmt/` (syntax.h, format.h, main.cpp, test.cpp), a separate CMake target. `dev/src` doesn't change at
  all. syntax.h is a parser of its own (about 1300 lines, like go/parser) driving `lex.h` unchanged; what doesn't parse
  is refused. `src/lint.py` uses it (`~/Dev/lobster/bin/lobsterfmt`, copied there by hand).
- **Limits:** a name that's both a function and an enum value from another file: `size+1` stops compiling, and a
  variable named like an imported namespace with `ns.size-1` silently becomes a call. `a-1` stays tight unless `a` is
  a variable it can see. New syntax in parser.h has to be added to syntax.h. Built on macOS only.

- [ ] Close #466 with a note to Wouter
- [x] Finish it, with an arbiter (no lexer change needed)
- [x] `lint.py` no longer needs `parsed_tokens` (`gl.window_icon` in the stash still matters)

## 11. LSP (#459)

- **What and why:** whole-program checking, references, rename, completion and more, from the Zed
  extension work.
- **Right or wrong?** Not about usage.
- **State:** waiting on Wouter, who said it's "a bit harder to review all together".
- **Flag:** this breaks our one-change rule, since it's many features in one PR, 24 commits, even if they're tidy.

- [ ] Decide: leave it, or split it

## 12. Local only: `gl.window_focused` and frame sleep

- **What:** lower the frame rate in the background (`src/game/pace.lobster`), and sleep out the frame
  cap in one long sleep (context switches about 2,100 to 1,400 a second).
- **Why:** the laptop running hot.
- **State:** on branches `window-focused` and `frame-sleep`. You said don't PR, so they stay local.

## Our Lobster differs from master

The game builds against `~/Dev/lobster` (branch `lsp-index`), which carries the pool, `gl.draw_mesh`,
`gl.buffers_made`, `gl.window_focused`, frame sleep and the LSP commits. It won't build on upstream
master. `gl.text_list` isn't in that branch, which is further evidence the game doesn't need it.

## Already merged

#461 and #465 (docs), #467 (`--mir` and `qsort_in_place` fixes), #470 (CI pin).

## Noticed, not planned

Upstream master doesn't build here with warnings as errors: `sprintf` in `stb_image_write.h` and an
unused label at `gltexture.cpp:206`. I build with `LOBSTER_WERROR=OFF`. It's a separate PR if you
want it.

## Suggested order

1. Touch repro (item 4), which also tests the game fix (item 5).
2. `ReadTexture` (item 6).
3. Measure `gl.draw_mesh` (item 8).
