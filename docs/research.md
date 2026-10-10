# Research notes

Technical reference behind `mvp-plan.md`, from the October 2026 research pass. Treat community
projects as patterns, not proven libraries, and verify claims marked *unverified* before relying
on them.

## Engine

- **Godot 4.7.2 stable** (4.7 released June 18, 2026; 4.7.2 on August 18, 2026). Godot 4.8 was
  in feature freeze (dev 7, September 29, 2026), with a Q4 2026 release estimated. Don't chase it
  mid-project.
- Standard build + GDScript. Use .NET only if moving the sim to C# fixed-point (Klotho/Ferrostorm
  style); it adds a toolchain.

## Lockstep and determinism

- **Classic RTS lockstep** (Bettner and Terrano's GDC 2001 networking paper): sending unit state
  "would limit us to 250 moving units". The fix was simultaneous simulation: ~200 ms turns, commands
  issued in turn N execute at N+2, over UDP.
- **Godot lockstep projects (2026, young):**
  - Ferrostorm (fixed-point C# sim, Godot 4.7 .NET client, relay compares hashes every 30 ticks):
    <https://github.com/lgreene03/ferrostorm>
  - Meridian Fracture (GDScript, 4.7.2, lockstep LAN RTS for up to 8 players, desync diagnostics):
    <https://github.com/x42553/meridian-fracture>
  - Klotho (32.32 fixed-point lockstep/rollback for Godot .NET 4.4+): <https://github.com/xpTURN/Klotho>
  - Project Nexus (GDScript fixed-point, SCALE=1000, lockstep over ENet).
- **Desync causes:**
  - Floats across CPUs and compilers.
  - Unordered dictionary iteration. ReSun: "Replace sim-affecting dict iteration with indexed arrays",
    <https://github.com/ReSun-Developers/ReSun/issues/290>
  - Float maths in AI code. Kronland: `Math.hypot` "not guaranteed to round the same way",
    <https://github.com/wi-wissen/Kronland/issues/7>
  - Unseeded RNG.
  - Physics/RVO: Godot physics and avoidance are float-based. The Box2D GDExtension lists "Missing
    cross platform determinism".
- Debugging desyncs: <https://bugnet.io/blog/how-to-debug-desync-in-deterministic-lockstep-games>

## Godot 2D rendering and the composer

- **Skeleton2D/Polygon2D:** needs hand-painted weights per polygon, which doesn't suit generated
  parts. The 2D IK modifications (`SkeletonModification2DCCDIK`/`FABRIK`) are Experimental and
  misbehave with mirrored rigs; EasyIK exists to fix that.
  <https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html>,
  <https://github.com/IUXGames/EasyIK>
- **2D batching** came to Forward+/Mobile in Godot 4.4 (Stuart Carnie, GH-92797). One tilemap case
  went from ">573440" draw calls to "36". Many unique textures or materials break batches.
- **Sprite2D node overhead:** in one Godot forum test (Godot 4.2.1), 4,096 sprites ran at ~250 FPS,
  against ~270 FPS through RenderingServer. That's a single-machine anecdote, so profile it yourself.
  <https://forum.godotengine.org/t/2d-rendering-performance/45719>
- **MultiMeshInstance2D:** one draw for many instances, with per-instance transform, colour and
  custom data, but not per-instance textures. Use a single atlas and pass UV rects in custom data.
  <https://docs.godotengine.org/en/stable/classes/class_multimeshinstance2d.html>
- **Palette swap:**
  - The UV-lookup recolour technique: <https://godotshaders.com/shader/palette-swap-no-recolor-recolor/>
  - KoBeWi's shader: <https://github.com/KoBeWi/Godot-Palette-Swap-Shader>. Its README notes that in
    Godot 4 "`COLOR` also includes modulate", which is what enables the "params in modulate" trick.
    That batching behaviour is *unverified*, so test it.
- **SVG:** rasterised at import by ThorVG, which supports only a subset: no filters, and text must
  be converted to paths. `DPITexture` and `Image.load_svg_from_string` rasterise at runtime, which
  is useful for modded parts.

## Pathfinding

- Flow fields are the standard RTS crowd tool: one solve per target serves a whole group.
- `AStarGrid2D`: fast, with jump-point search, but `jumping_enabled` ignores weights. Float-costed,
  and its cross-platform determinism is undocumented.
  <https://vav-labs.com/blog/astargrid2d-complete-reference/>
- `NavigationAgent2D` avoidance "has a significant performance cost" with many agents, and is
  float and threaded.
- Comparison of the options: <https://vav-labs.com/blog/godot-pathfinding-addons-compared/>

## Reference projects

- **Godot Open RTS** (Lampe Games, MIT, Godot 4.3, 3D): "1 species, 2 resources", up to 8 players,
  human vs AI. Good for selection UI, match flow and a simple AI.
  <https://github.com/lampe-games/godot-open-rts>
- **OpenRA:** YAML rules are a good model for data-driven civ JSON.
- **0 A.D.** and **Beyond All Reason** (Recoil engine): lockstep with sync hashes, economy pacing, and
  community-driven RTS that took years.

## Godot <-> Holepunch bridge

- **Prior art:** no project, addon or forum post connecting Godot to Hyperswarm/HyperDHT turned up.
  The pieces all exist, but budget a spike for it.
- Holepunch's `snake` example runs Hyperswarm "inside an embedded Bare worker" and talks to the UI
  with "a simple JSON IPC protocol". <https://github.com/geordangesink/snake>
- **Bare** embeds through its C API (`bare_setup`/`bare_load`/`bare_run`);
  `bare-macos`/`bare-windows` show worklets in native hosts. <https://github.com/holepunchto/bare>
- **Godot side:**
  - `OS.create_process` spawns the sidecar. The child "will not terminate when Godot terminates",
    so kill it on `NOTIFICATION_WM_CLOSE_REQUEST`, and make the sidecar exit when its socket drops.
  - `OS.execute_with_pipe` uses stdio instead; read the pipe on a Thread.
  - `WebSocketPeer` (call `poll()` every frame), `PacketPeerUDP` and `StreamPeerTCP` are all available.
  - You can't execute binaries from `res://`, so ship the sidecar next to the export.
- **NAT:** hole punching "works on most consumer networks; it is not guaranteed on every corporate
  or symmetric-NAT setup". Blind relays are the fallback. HyperDHT #303 notes the app currently
  "carries no indication that it is relayed", so measure RTT and adapt turn length.
  <https://docs.pears.com/p2p/explanation/peer-to-peer-demystified/>,
  <https://github.com/holepunchto/hyperdht/issues/303>
- **Protomux:** messages within a channel arrive in order; use `cork()`/`uncork()` to batch a turn.
  <https://github.com/holepunchto/protomux>
- **Third-party DHT ports:** hyperdht-cpp self-reports "~93%" parity; peeroxide is in Rust.
  Both are *unverified*.

## Mods and packs

- `ProjectSettings.load_resource_pack` (PCK/ZIP) can carry scripts, and the docs have a "Security
  concerns" section. Keep shared mods data-only.
  <https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html>

## Multiplayer options compared

| Option | RTS fit | Effort | Risk | Verdict |
|---|---|---|---|---|
| Godot high-level multiplayer (Spawner/Synchronizer, RPC) | Poor: replicates state (the 250-unit trap) | Low then high | Bandwidth, authority rewrites | At most a dumb pipe for a LAN test |
| Lockstep, own messages, ENet/UDP LAN | Excellent | Medium | Desyncs (mitigated by tests) | Good intermediate step |
| **Lockstep over a Hyperswarm sidecar** (localhost WebSocket) | Excellent, plus NAT traversal and key matchmaking | Medium | Process management, relay latency | **Recommended** |
| Custom `MultiplayerPeerExtension` | Only for Godot RPCs | Medium-high | Unneeded for lockstep | Skip |
| GDExtension embedding Bare / hyperdht-cpp | Best packaging | High | High | Only if the sidecar proves painful |
