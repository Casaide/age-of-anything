# AI sprite generators for 8-facing RTS units, and keeping one style (as of Oct 2026)

Scope: direct 2D generation of directional and animated sprites (vendor tools and open models), the hybrid of
3D renders repainted by ControlNet or img2img, style consistency at scale, APIs, cost, running locally on Apple
Silicon, and real reports from developers. Research ran 2026-10-31 with about 15 searches and fetches. Most sources are
vendor pages or vendor-written comparisons, so treat their quality claims as marketing unless noted. I found no
independent benchmark of facing consistency for any tool.

## Tools: what each does for 8 facings and animation, and at what resolution

### Takeaway
Three hosted tools say they make 8 facings plus animation: PixelLab (pixel art), Ludo (via a 3D model inside), and God
Mode AI. They work one character at a time, from a reference image, at small sizes: PixelLab's Pro 8-rotation tool caps
at 168x168 per frame, and Retro Diffusion uses fixed 32 and 64 px sizes. None documents swappable parts, mount layers or
team-colour masks. Scenario, Leonardo and Layer are general image platforms that rely on trained models; they do not
make directional sprites natively.

### Cited Findings
- **PixelLab, 8 rotations (Pro):** outputs eight facings (S through SW) in one 3x3 grid, the centre cell a reference. Each frame is at most 168x168 px. It costs 10, 15 or 25 "generations" per run for frames up to 85, 113 and 168 px. It has three modes: create with style, create from concept plus style (up to four concept images, max 1024 px), and rotate character (one reference facing in, the other 7 out). Options are view (low top-down, high top-down, side), body type (bipedal, quadrupedal), transparent background and seed. Needs a Tier 1 subscription. The docs make no claim about consistency. — [PixelLab docs](https://www.pixellab.ai/docs/tools/create-8-rotations-pro)
- PixelLab's site advertises 4 and 8 facings "for isometric and top-down games", isometric support, animation three ways (one-click, skeleton-based, text-prompted walk, run and attack), and reference images to keep sprites consistent. Plan prices did not load. — [PixelLab](https://www.pixellab.ai/)
- A third-party September 2026 comparison: PixelLab does 4 or 8 facings with skeleton posing, up to 400x400 on the top tier, on a true pixel grid. A free trial gives 40 generations; plans cost $12, $24 and $50 a month. Consistency comes from per-project references. — [Cinevva guide, Sept 2026](https://app.cinevva.com/guides/ai-pixel-art-generators). (The 400x400 here does not match the 168 px Pro-rotation cap above. They are probably different tools in PixelLab; unverified.)
- PixelLab API: the REST API is at api.pixellab.ai/v2/docs (the page would not render for me). Community MCP servers wrap tools such as `generate_8_rotations_v3`, create a persistent 8-facing character, and add animations to it. One MCP changelog removed a 4-direction endpoint that did not exist in the API, so names in third-party wrappers drift. — [pixellab-forge-mcp releases](https://github.com/rabbitcannon/pixellab-forge-mcp/releases), [oomol skill listing](https://oomol.com/es/skills/oo-pixellab/)
- **Retro Diffusion:** pixel art only. An HTTP API (`POST /v1/inferences`) makes images, animations and tilesets. The RD Pro model takes up to 9 reference images for character consistency at $0.18 an image; a sample call cost about $0.058. A hosted MCP server offers 18 tools, including Pixel Fixer, which recovers the native pixel grid from upscaled or AI-softened art. The rate limit is 10 requests a minute per key. — [Retro Diffusion api-examples (GitHub)](https://github.com/Retro-Diffusion/api-examples), [MCP listing](https://mcpservers.org/id/servers/retro-diffusion/retro-diffusion-mcp)
- Retro Diffusion has fixed sizes (32, 64) and an Aseprite extension at $20 to $65 one-time; otherwise it is pay-as-you-go. — [SpriteCook comparison (a competitor), 2026](https://www.spritecook.ai/compare/retro-diffusion); web credits from $5 for 250 — [Cinevva](https://app.cinevva.com/guides/ai-pixel-art-generators)
- **Ludo.ai:** its "Directional Sprites" renders one character in up to 8 matching facings *from a single 3D model* (so it is a 3D-intermediate method). "New Direction" turns a finished animation to another angle. Sheets run up to 64 frames and about 5 s, driven by a prompt, up to 3 keyframes, a reference video or presets (walk, run, idle, attack). It has 32 styles (5 pixel) and is reachable by API, MCP and CLI. Paid plans start at $20 a month ($15 billed yearly) and Pro is $50. It does **not** train custom models on your art. — [Ludo's own comparison, Oct 2026](https://ludo.ai/compare/best-ai-sprite-generators)
- **God Mode AI:** upload a character image and choose from about 100 actions and views, including 8-direction isometric walk, run and combat; also Spine 2D, 3D animation and 360° rotation. Pricing conflicts: $12 credit packs plus $19 a month in one listing; $29 a month or a $32 pack, with subscription generations public, per Ludo. — [aggregator listing](https://aisotools.com/tool/god-mode-ai), [Ludo comparison](https://ludo.ai/compare/best-ai-sprite-generators)
- **Scenario:** a general platform. Turnarounds come from prompt edits, a video model's 360° effect, or custom-trained character models with ControlNet. For sprites it suggests a side-view base, then a sheet made by a general image model (it names GPT Image 2 or Gemini 3.1). Consistency rests on custom LoRA or multi-LoRA models; custom training is on the $45 a month Pro plan. — [Scenario turnarounds blog](https://www.scenario.com/blog/generate-character-turnarounds-scenario), [Scenario spritesheets help](https://help.scenario.com/articles/9088582240-create-spritesheets-with-scenario), [Ludo comparison](https://ludo.ai/compare/best-ai-sprite-generators). SpriteCook says Scenario's sprites come from prompting general models, and you slice and assemble them yourself. — [SpriteCook compare/scenario](https://www.spritecook.ai/compare/scenario)
- **Leonardo:** output is not on a pixel grid and needs downscaling, palette reduction and outline cleanup; it has no sprite animation; consistency comes from fine-tuned models; plans cost $12, $30 and $60 a month. **Layer:** limited animation, custom-trained models, from $10 a month. **Sprite-AI:** static props and icons only, no animation, $8 a month. — [Cinevva, Sept 2026](https://app.cinevva.com/guides/ai-pixel-art-generators)
- Other cheap sprite tools are AutoSprite (animation-first, $12 a month), SpriteCook (API on every plan, $8 a month) and SpriteLab ($7.99 a month). — [Ludo comparison](https://ludo.ai/compare/best-ai-sprite-generators)

### Inferences
- Every dedicated tool works on whole characters. A recipe-built roster (body + head + weapon + armour + mount, in this
  game about 5 roles x N races x 4 ages, each generated live from a prompt) would need every combination generated as its
  own character, or the parts generated separately and composited. No tool offers layered output with sockets.
- No tool makes a team-colour mask. You would have to get one by keying a fixed flag colour in the prompt, or by
  segmenting afterwards, and both are fragile across 8 facings x N frames.
- At 168 px a frame and below, these tools fit "small units" in size. The game bakes at 2x (`ART_SCALE` 3.0), so sizes
  are probably fine, but nearly all of them target pixel art, not the painterly look.
- Ludo's 8-facing method uses a 3D model inside. That is evidence that the vendors themselves get facing consistency
  through 3D rather than pure 2D diffusion.

### Gaps
- No independent, measured test of facing consistency (same armour detail and colours across the 8 facings) for
  PixelLab, God Mode or Ludo. Neither r/aigamedev nor r/gamedev threads came up in search.
- PixelLab's API price per call and its current plan prices (the plans page did not load; the third-party figures may
  be stale).
- Whether any tool takes a fixed palette or a mask channel as input.

## Open models: Flux, SDXL, Qwen Edit, ControlNet, multi-view diffusion

### Takeaway
Open multi-view models (MV-Adapter, Zero123++) and multi-angle edit LoRAs (Qwen Image Edit, Flux Kontext) can turn a
character to new angles. Papers show blur and lost detail in some views, and nothing is tuned for 8 facings at a 3/4
isometric elevation with small sprites. They are tools for making concepts and LoRA training data, not finished 8-facing
sprites.

### Cited Findings
- MV-Adapter is the only one of the compared methods trained on orthographic renders (6 views per object) — [ViewMask-1-to-3, arXiv 2512.14099](https://arxiv.org/pdf/2512.14099), [MV-Adapter ICCV 2025 supplement](https://openaccess.thecvf.com/content/ICCV2025/supplemental/Huang_MV-Adapter_Multi-View_Consistent_ICCV_2025_supplemental.pdf). Zero123++ uses alternating elevations (+30°/-20°); MV-Adapter uses 0° elevation. — [GeoMVD, arXiv 2511.12204](https://arxiv.org/pdf/2511.12204)
- On a Mario model, Zero123++ showed artifacts or lost detail in some views, and MV-Adapter (SDXL) "generates blurry images in certain views". This comes from a competing paper. — [GeoMVD](https://arxiv.org/pdf/2511.12204)
- Cartoon meshes with little detail make depth maps ambiguous: front and back get confused, and faces appear on several sides. — [ConTEXTure, arXiv 2407.10558](https://arxiv.org/html/2407.10558v1) (2024, older)
- Qwen Image Edit has a multi-angle LoRA trained on 96 viewpoints of the same object, steered by a camera-control node in ComfyUI; it needs Qwen-Image-Edit-2511. — [stable-diffusion-art.com](https://stable-diffusion-art.com/qwen-image-edit-multiple-angle-lora/), [weirdwonderfulai](https://weirdwonderfulai.art/comfyui/qwen-edit-2509-lora-camera-multi-angle/)
- Flux Kontext keeps characters consistent across repeated edits (per its paper). A community turnaround LoRA gives front, profile, 3/4 and back views and works best on full-body stylised characters. These are used to build LoRA training sets from one reference. — [FLUX.1 Kontext paper](https://arxiv.org/html/2506.15742v2), [RunComfy turnaround workflow](https://www.runcomfy.com/comfyui-workflows/flux-kontext-lora-multi-view-turnaround-sheet), [Floyo workflow](https://www.floyo.ai/workflows/flux-kontext-single-image-to-charact-sw6872x86u3k)

### Inferences
- These models give 4 to 6 canonical views, usually at eye level. An isometric RTS needs 8 facings at a fixed 3/4
  elevation, so the diagonals and the elevation would have to come from prompts or camera LoRAs. That adds drift.

### Gaps
- No source tests these models on small isometric sprites or on 8 facings.

## The hybrid: 3D depth or normal maps per facing, then ControlNet or img2img

### Takeaway
Depth ControlNet holds silhouette and proportions well; that part works. The weak point is detail and colour that
change from frame to frame and facing to facing, because each image is denoised on its own. The known fixes are
TemporalNet, attention injection, low denoise and a fixed seed, and they reduce the flicker without removing it.
Lowering denoise to fight flicker can also shift colours. For sprites, palette locking and a pixel-grid cleanup are also
needed. No source showed a shipped sprite pipeline doing this for 8 facings with walk cycles.

### Cited Findings
- On the same reference, plain img2img changed shapes and adornments, while depth ControlNet kept shape and proportions. — [Scenario help, comparing](https://help.scenario.com/comparing)
- A typical ComfyUI setting: VAE-encode the source, denoise 0.6 to 0.9, depth strength 0.6 to 1.0. The control image fixes the structure; the source supplies style and detail. — [ComfyUI ControlNet guide (Mintlify mirror)](https://www.mintlify.com/Comfy-Org/ComfyUI/guides/controlnet)
- Generating frame by frame with Stable Diffusion flickers. The remedies are multi-frame rendering or attention injection. — [MMagic ControlNet animation docs](https://mmagic.readthedocs.io/en/stable/model_zoo/controlnet_animation.html) (2023, older but still the standard explanation)
- TemporalNet feeds the previous frame back in (weight 0.6 or less). Lower denoise reduces flicker but can shift colours. — [toyxyz / TemporalNet script summary](https://toyxyz.gumroad.com/l/jydvk) (older)
- AI edits of sprites tend to add new colours and break palette limits. — [pixie.haus (vendor)](https://origin.pixie.haus/resources/edit-iterate-engineering-variations-with-image-to-image-ai)
- Retro Diffusion's Pixel Fixer recovers a clean pixel grid from softened AI output, which could clean up repainted renders. — [Retro Diffusion MCP listing](https://mcpservers.org/id/servers/retro-diffusion/retro-diffusion-mcp)

### Inferences
- The engine already bakes per-part sprites with a team mask, from the same 3D source. If the repaint adds detail, the
  mask region (and the part boundaries the composer uses) stops lining up with the painted pixels. Doing it right
  would mean repainting with the mask region held fixed (inpainting outside the mask) or re-deriving the mask.
- A cheaper and steadier option: use AI to paint the *textures* on the 3D parts once (as a consistent material set),
  then keep the deterministic bake. The repaint happens once per part, not per frame, so nothing can flicker. This is
  inferred, not sourced.

### Gaps
- No measured flicker test on walk cycles at sprite size, and no RTS or isometric devlog using this pipeline.

## Style consistency at scale: LoRAs, reference images, seeds

### Takeaway
The main levers are a style or character LoRA trained on your own art (Scenario, Layer, Leonardo, local Kohya)
and reference-image conditioning (PixelLab's per-project references, Retro Diffusion's up to 9 refs). A vendor guide
puts realistic consistency at roughly 85%, so plan on cleaning up by hand. One developer's report: a trained LoRA
improved continuity, but the work was no less than making 3D renders.

### Cited Findings
- Scenario keeps a "locked, custom-trained house style" on its $45 a month Pro plan; Ludo does not train on your art. — [Ludo comparison](https://ludo.ai/compare/best-ai-sprite-generators)
- Scenario's dual-character workflow uses LoRA or multi-LoRA for "guaranteed consistency" (vendor claim). — [Scenario help](https://help.scenario.com/en/articles/using-a-dual-characters-model-to-create-a-scene-sequence)
- A realistic 2026 expectation is about 85% consistency, with manual cleanup. — [Lovart guide (vendor)](https://www.lovart.ai/ja/blog/complete-guide-consistent-ai-character-design), via search summary
- Tools sorted by how they get consistency: per-project references (PixelLab), prompts only (Retro Diffusion lite), custom models (Scenario, Layer), fine-tunes (Leonardo), style presets (Ludo), none (Sprite-AI). — [Cinevva, Sept 2026](https://app.cinevva.com/guides/ai-pixel-art-generators)
- A developer of *California Strip Poker* moved from 3D renders to AI art and trained a LoRA per character. Continuity improved, but "I can't say this was less work than the equivalent 3d renders". Hands and feet were fixed by inpainting or hidden. — [itch.io devlog comment (about 2 years old, so ~2024, older)](https://itch.io/post/9221790)
- Plain text-to-image gives a different character each time; img2img holds proportions and posture. — [pixie.haus (vendor)](https://pixie.haus/resources/edit-iterate-engineering-variations-with-image-to-image-ai)

### Inferences
- With hundreds of units in one style, the generated units drift in small details (outline weight, light direction,
  saturation). A LoRA trained on the game's own best bakes, plus a fixed light direction set by the depth or normal
  control, is the strongest open combination, but no source shows it holding across hundreds of units.

### Gaps
- No public example of a game shipping hundreds of AI-made units across 8 facings in one style.

## APIs, cost, and running locally on Apple Silicon

### Takeaway
All the main hosted tools have APIs or MCP servers (PixelLab, Retro Diffusion, Ludo, SpriteCook, Scenario). A
generated character costs roughly cents to tens of cents. Running locally on a Mac is workable for SDXL and Flux. Draw
Things is the fastest Mac runner; ComfyUI on MPS is 2 to 4x slower than CUDA and needs fp16, and Flux in ComfyUI wants an
M3 or M4 Max with 64 GB or more.

### Cited Findings
- Retro Diffusion: $0.18 an image on RD Pro, 10 requests a minute. — [api-examples](https://github.com/Retro-Diffusion/api-examples)
- PixelLab: 10 to 25 generations per 8-rotation run, depending on size. — [PixelLab docs](https://www.pixellab.ai/docs/tools/create-8-rotations-pro)
- Ludo API, MCP and CLI calls use credits even on the $50 a month Pro plan. — [Ludo](https://ludo.ai/compare/best-ai-sprite-generators)
- ComfyUI on MPS is 2 to 4x slower than CUDA; use `--force-fp16` (fp32 is the Mac default, at half the speed). ComfyUI's docs list SDXL on M2 Pro and up or M3/M4, and Flux on M3/M4 Max or Ultra with 64 GB or more. — [ComfyUI hardware support (Mintlify mirror)](https://mintlify.com/Comfy-Org/ComfyUI/configuration/hardware-support)
- Rough timings (sources conflict): M4 Pro 24 GB, Flux schnell at 1024² in about 10 to 15 s and SDXL in about 15 to 20 s — [localaimaster](https://localaimaster.com/blog/local-image-generation-mac); Flux Dev about 15 to 25 s on 24 GB in Draw Things — [insiderllm](https://insiderllm.com/guides/stable-diffusion-mac-mlx/)
- Draw Things claims a 4.6x speed-up from Metal FlashAttention v2.5 on M5 (vendor). — [Draw Things releases](https://releases.drawthings.ai/p/metal-flashattention-v25-w-neural). It is up to 25% faster than mflux for Flux (on an M2 Ultra) — [insiderllm](https://insiderllm.com/guides/stable-diffusion-mac-mlx/)
- A community fp8 node for ComfyUI on Apple Silicon gave about 22% on an M2 Max and nothing on an M3 Ultra. — [ComfyUI-AppleSilicon-FP8](https://github.com/pawel-mazurkiewicz/ComfyUI-AppleSilicon-FP8)

### Inferences
- In this game, races are generated live from prompts, and the sim must be deterministic. Any AI step therefore has
  to be offline, at authoring time, producing fixed art per part, never per prompt at runtime. That fits the
  "fixed art prebaked and shipped" rule. Cloud APIs would also make the game depend on a vendor.

### Gaps
- No Mac benchmark for ControlNet and LoRA stacks at sprite batch sizes.

## Image-to-3D (the other hybrid: AI concept image, then a 3D model, then the existing baker)

### Takeaway
TRELLIS.2 (open, Microsoft) and Hunyuan3D are the leading image-to-3D models in 2026. Reviews favour Hunyuan for
quality and TRELLIS.2 for speed and GLB export. No source tests them on stylised characters or on readiness for
rigging, and the game's baker needs rigged legs and socketed parts.

### Cited Findings
- "Hunyuan 3D when quality matters, Trellis 2 when speed and cost matter." — [3D AI Studio (vendor blog), 2026](https://www.3daistudio.com/blog/trellis-2-vs-hunyuan-3d-differences-explained)
- TRELLIS.2 is described as the fastest to iterate on, with GLB export, for game assets. — [Wavespeed](https://wavespeed.ai/blog/3d-model-access/best-ai-tools-for-3d-game-assets/), [ComfyUI wiki, Dec 2025](https://comfyui-wiki.com/en/news/2025-12-18-microsoft-trellis2-3d-generation)
- Input advice: 1024 px or more, a plain background, several views. — [lilting.ch](https://lilting.ch/en/articles/ai-3d-generation-tools-comparison)
- Hunyuan3D Studio (arXiv 2509.12815) describes a pipeline aimed at game-ready assets (the paper's own framing). — [arXiv](https://arxiv.org/abs/2509.12815)
- An indie developer generated a character image (Pony Diffusion), then a textured 3D model from it with another tool. — [itch.io post](https://itch.io/post/16091946)

### Inferences
- This route keeps everything that already works (8 facings, keyed legs, sockets, team masks, the placement check)
  and only raises the quality of the meshes and textures. It is the hybrid most likely to fix "looks cheap" without
  breaking the parts system. The cost is cleanup: generated meshes come as one fused piece, and they would need splitting
  into parts and anchors.

### Gaps
- Whether TRELLIS.2 or Hunyuan meshes split cleanly into separate parts (body, head, weapon), and whether they run on
  Apple Silicon (most target CUDA; not verified).

## Real reports from developers shipping AI sprites (2025-2026)

### Takeaway
The evidence from developers is thin. I found no RTS or isometric game that publicly ships AI-made 8-facing unit sprites at
scale. The player-reception risk is real. Steam requires disclosure of AI content made during development (the policy was
reworded in January 2026), and 15,000+ games carry the label. Backlash hits obviously-AI art (Crimson Desert, March 2026:
the studio audited and replaced its AI 2D props).

### Cited Findings
- Steam's disclosure covers AI content made during development and content generated at runtime. Code assistants are
  exempt after the January 2026 rewrite. SteamDB lists more than 15,000 titles with the label. — [stuff.co.za, Feb 2026](https://stuff.co.za/2026/02/12/are-video-game-developers-using-ai-players-want-to-know-but-the-rules-are-patchy/), [GameFromScratch](https://gamefromscratch.com/steam-makes-massive-update-to-ai-generation-policy/)
- Crimson Desert shipped generative AI 2D props. After player criticism, Pearl Abyss audited them and replaced each one with original paintings. — [Outlook Respawn](https://respawn.outlookindia.com/gaming/gaming-news/pearl-abyss-launches-audit-after-ai-art-found-in-crimson-desert), [Gigazine, 2026-03-23](https://www.gigazine.net/gsc_news/en/20260323-crimson-desert-ai-art)
- FragPunk was criticised for undisclosed AI assets. — [Notebookcheck](https://www.notebookcheck.net/New-hit-FPS-FragPunk-comes-under-fire-for-using-AI-art-with-no-Steam-disclosure.976414.0.html)
- A vendor argues the backlash targets generic, obviously-AI output (biased source). — [SpriteCook blog, June 2026](https://www.spritecook.ai/blog/is-ai-art-ok-in-indie-games)
- Tim Sweeney argues for dropping the disclosure label. — [allthings.how](https://allthings.how/why-tim-sweeney-calls-steam-s-ai-disclosure-rule-irresponsible/)

### Inferences (overall verdict for this game)
- **Direct 2D generation cannot meet all five needs today.** 8 facings: partly met (PixelLab, God Mode, Ludo), with no
  independent proof of consistency. Animation frames: met per character. **Swappable parts: not met by any tool.**
  **Team-colour mask: not met by any tool.** Hundreds of units in one style: not shown anywhere; it would mean about 85%
  consistency plus cleanup by hand, per unit and per facing. The generator makes races from prompts, which multiplies
  the combinations beyond anything that can be generated whole.
- The steadiest path keeps the 3D-to-bake pipeline (it already solves facings, parts, mask, legs and determinism) and
  uses AI at authoring time to raise the source quality: AI concepts turned into meshes (TRELLIS.2 or Hunyuan3D), or
  AI-painted textures and materials on parts, possibly a one-off LoRA-guided paint-over of *static* reference bakes to
  set the target. Per-frame AI repainting is the least steady option (flicker, palette drift, mask mismatch).
- An AI disclosure on Steam would be needed for any of these routes. The audience punishes art that is obviously AI,
  which is another reason to keep a deterministic, hand-directed bake as the final step.

### Gaps
- No r/aigamedev, r/gamedev or YouTube head-to-head of the tools surfaced in search. Nobody reported shipping AI sprites in an RTS.
