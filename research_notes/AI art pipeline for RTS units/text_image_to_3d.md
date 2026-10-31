# Text-to-3D and image-to-3D generators, as of October 2026 (for a solo dev's RTS parts kit)

Scope: which generators are current, mesh quality and topology, part separation, creatures, style consistency, Apple
Silicon vs cloud, licences (UK/EU developer). Research done 2026-10-31. Most comparison pages found are vendor-written
or vendor-adjacent (3D AI Studio, Neural4D, Tripo, Sloyd, Ludo, Summer Engine); they are flagged where used. No
independent, measured head-to-head benchmark across Meshy / Tripo / Rodin turned up.

## 1. Which generators are current and best (Oct 2026), and which give game-ready meshes

### Takeaway
The commercial front line in Oct 2026 is Meshy 7.1 (Sept 2026), Tripo H3.1 (Feb 2026, with a v3.5 texture model from
Aug 2026), and Rodin Gen-2.5 (May 2026); CSM is gone (bought by Alphabet, Jan 2026). The best open model you can
legally use in the UK/EU is Microsoft's TRELLIS.2 (4B, Dec 2025, MIT); Hunyuan3D's open weights are excluded in the
UK/EU and Hunyuan3D 3.x is cloud-only. Only Tripo exposes explicit low-poly / quad face-count controls in its API.

### Cited Findings

**Commercial**
- Meshy: API model list has `meshy-7.1` as "latest", plus `meshy-6`, `meshy-6-lite`, and legacy `meshy-7`; the old
  `lowpoly` model "retires Oct 30, 2026" — [Meshy API pricing](https://docs.meshy.ai/api/pricing)
- Meshy 7 released 10 Aug 2026, 7.1 on 10 Sept 2026 (third-party blog, not an official Meshy page) — [Neural4D blog](https://blog.neural4d.com/comparisons/meshy-7-release-date-and-alternative/); 7.1 described as quad or triangle mesh with one-step character rigging — [Summer Engine model page](https://www.summerengine.com/models/meshy-7-1)
- Meshy offers Remesh (5 credits), UV unwrap (5), rigging (5), animation (3 per action) as separate API calls — [Meshy API pricing](https://docs.meshy.ai/api/pricing)
- Tripo H3.1 (`v3.1-20260211`) is the default "current stable release"; older v3.0-20250812 and v2.5-20250123 remain; `v3.5-20260815` is a texture model. Inputs: text, single image, multiview; PBR output — [Tripo developer docs, H3.1](https://developers.tripo3d.com/en/models/v3-1)
- Tripo H3.1 topology controls: quad mesh in FBX (up to 150k faces, 10k default), "smart low-poly" at 500–20,000 faces (500–10,000 with quad), standard up to 1.5M faces, detailed up to 2M; ~40 s untextured, ~120 s textured — [Tripo developer docs](https://developers.tripo3d.com/en/models/v3-1)
- Tripo 3.0 launched Aug 2025 with "intelligent part segmentation" and higher-precision textures — [Business Wire press release](https://www.businesswire.com/news/home/20250820723593/en/Tripo-the-Frontrunner-of-3D-AI-Boom-Supercharges-New-Era-in-Content-Creation-with-3.0-Upgrade)
- Rodin Gen-2.5 (Deemos / Hyper3D) shipped May 2026 (one source says 26 May); reported up to ~10M polygons, five geometry tiers, textures up to 12K, plus a Fast variant. Specs come from resellers/press, not an official Hyper3D page — [Scenario help](https://help.scenario.com/articles/3791851266-rodin-hyper3d-gen-2-5-models-the-essentials), [Mind-Verse](https://mind-verse.de/news/neue-moeglichkeiten-3d-generierung-rodan-gen-25), [3D AI Studio](https://www.3daistudio.com/Models/Rodin-Gen-2-5)
- Deemos raised new funding in June 2026 for Rodin's global rollout — [Yicai Global](https://www2.yicaiglobal.com/news/chinese-ai-startup-deemos-raises-new-funds-for-hyper3d-rodins-global-rollout)
- April 2026 comparison (StraySpark): Meshy 5 30–90 s/generation, "remesh tool produces acceptable game topology"; Rodin Gen-2 Hyper mode 3–8 min, most detailed but dense mesh needing retopology; Tripo fastest; CSM Cube 2 had the best retopology-aware quad flow. Update of 25 Sept 2026: "CSM is no longer an option" — Alphabet acquired Common Sense Machines (closed 24 Jan 2026) and csm.ai no longer resolves — [StraySpark](https://www.strayspark.studio/blog/generative-3d-tools-comparison-meshy-rodin-tripo-csm-2026)
- Consensus across 2026 roundups (vendor-written): Tripo fastest for iteration, Meshy best all-round / stylized game assets, Rodin cleanest topology / highest detail for hero assets; one names Rodin for "character / creature work" and Sloyd for "clean low-poly assets, no cleanup" — [techsy.io](https://techsy.io/en/blog/best-ai-game-asset-generators), [Medium roundup](https://medium.com/ideas-with-wings/best-ai-3d-model-generators-in-2026-tripo-ai-vs-meshy-rodin-kaedim-and-more-7eea7b05eb11), [ziva.sh](https://ziva.sh/blogs/best-ai-3d-asset-generators)
- Summer Engine (June 2026, a vendor): polycounts run "few-thousand to few-hundred-thousand" depending on quality; geometry usually quad-dominant or clean triangles; low-poly is mostly a prompt ("stylized, low poly"); AI geometry is a "first draft" for hero assets — [Summer Engine](https://www.summerengine.com/blog/ai-3d-game-asset-generator)
- Sloyd is a different kind of tool: $15/month Plus with unlimited generations (vendor's own comparison, dated 4 Sept 2025, possibly outdated) — [Sloyd blog](https://sloyd.ai/blog/3d-ai-price-comparison)

**Open weights**
- TRELLIS.2-4B (Microsoft, Dec 2025, arXiv 2512.14692): O-Voxel sparse representation (handles open surfaces, non-manifold, cavities), flow-matching transformers; PBR GLB (base colour, roughness, metallic, opacity); on an H100 ~3 s at 512³, ~17 s at 1024³, ~60 s at 1536³; GLB export defaults to decimate to 1,000,000 faces with 4096 px textures; separate texturing pipeline for an existing mesh (`example_texturing.py`) — [TRELLIS.2 GitHub](https://github.com/microsoft/TRELLIS.2), [ComfyUI Wiki](https://comfyui-wiki.com/en/news/2025-12-18-microsoft-trellis2-3d-generation)
- Hunyuan3D-2.1 (13 June 2025; "first production-ready" open release): PBR texture pipeline; VRAM ~10 GB shape, ~21 GB texture, ~29 GB both — [Hunyuan3D-2.1 GitHub](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1). Older than mid-2025: treat as possibly outdated.
- Hunyuan3D 3.0: 3x modelling accuracy and 1536³ geometric resolution claimed; available through Tencent Cloud / the Hunyuan 3D engine; no source found for open weights — [ToolNavs](https://toolnavs.com/de/article/275-hunyuan3d-30-is-coming-ai-triple-accuracy-and-15363-resolution-3d-dit-reconstruc), [Dzine](https://www.dzine.ai/ko/tools/hunyuan3d-3-0/)
- Tencent's open lineup: Hunyuan3D-1, 2/2.1, HunyuanWorld-1.0, Hunyuan3D-Part, Hunyuan3D-Omni (controllable generation, last push 17 Oct 2025); open and cloud versions "may be different" — [ToolNavs](https://toolnavs.com/en/article/823-hunyuan-3-d-engine-global-shang-xian-mian-xiang-quan-qiu-chuang-zuo-zhe-de-ai-3), [gittrend Omni](https://gittrend.io/repo/Tencent-Hunyuan/Hunyuan3D-Omni)
- HY-World 2.0 (world model, not objects) open-sourced 16 Apr 2026 — [Longport](https://longportapp.cn/news/282954139)
- Stable Fast 3D and SPAR3D (SPAR3D announced CES, Jan 2025): Stability AI Community License — [Hugging Face SF3D](https://huggingface.co/stabilityai/stable-fast-3d), [Analytics Vidhya](https://www.analyticsvidhya.com/blog/2025/01/nvidia-and-stability-ai-team-up-to-launch-spar3d/). Both predate mid-2025: likely outdated relative to TRELLIS.2.

### Inferences
- For this game's units (small sprites baked at 8 facings), raw generator output (hundreds of thousands to a million
  faces, 4K textures) is far more than needed; the useful knobs are Tripo's smart low-poly (500–20k faces) or a
  decimate/remesh pass (Meshy Remesh, Blender) after generation. Since sprites are baked, topology matters less than
  for real-time rigs, except where parts must deform (legs) or socket cleanly.
- TRELLIS.2 is the strongest open option that a UK developer can legally use; Hunyuan3D 2.1 quality may be comparable
  but its licence rules it out (see section 6).

### Gaps
- No independent, measured quality benchmark (e.g. a public leaderboard) for Oct 2026 was retrieved; quality rankings above are vendor/blog opinion.
- Kaedim: no current (2026) facts found on pricing or product state.
- Official Meshy 7 / 7.1 release notes and official Rodin Gen-2.5 specs not retrieved.
- Whether Hunyuan3D 3.x (or a 3.1) has open weights: not confirmed either way.

## 2. Part separation: separate parts, segmentation, part-aware generators

### Takeaway
Commercial tools now offer parts, but as segmentation of one generated object (Tripo's `generate_parts`, Tripo/Meshy
post-segmentation), not as a socket-ready kit. Research part-aware generators (PartCrafter, OmniPart, PartPacker,
Hunyuan3D-Part's P3-SAM + X-Part) exist with code, but licences vary and PartPacker is non-commercial.

### Cited Findings
- Tripo H3.1 API `generate_parts` "generate editable segmented parts", +20 credits, but requires `texture=false` and `pbr=false` (untextured parts only) — [Tripo developer docs](https://developers.tripo3d.com/en/models/v3-1)
- Tripo 3.0 segments complex models "into logical parts after creation" for editing, retexturing, animation — [Tripo blog](https://www.tripo3d.ai/blog/introducing-tripo-new-algorithm3); older Tripo blog lists segmentation 40 credits and "part completion" 50 credits — [Tripo blog](https://www.tripo3d.ai/blog/what-3d-model-generation-api-can-convert-images-or-text-into)
- Meshy's API lists "Auto Split" (10 credits) under 3D printing tools — [Meshy API pricing](https://docs.meshy.ai/api/pricing)
- Hunyuan3D-Part: P3-SAM (native 3D part segmentation of any input mesh: features, part masks, part boxes) and X-Part (generates complete parts from the mesh + P3-SAM output); arXiv 2509.06784 and 2509.08643 (Sept 2025); the open X-Part is a "light version", the full version only in Hunyuan3D-Studio; recommended input is AI-generated meshes from Hunyuan3D 2.5 / 3.0 — [Hunyuan3D-Part GitHub](https://github.com/Tencent-Hunyuan/Hunyuan3D-Part)
- PartCrafter (arXiv 2506.05573, NeurIPS 2025): jointly generates multiple distinct part meshes from one RGB image, no pre-segmentation — [arXiv](https://arxiv.org/abs/2506.05573v1), [NeurIPS](https://neurips.cc/virtual/2025/poster/120299)
- OmniPart (arXiv 2507.06165, July 2025): plans a variable-length sequence of part bounding boxes guided by 2D part masks, then synthesises parts with a part-aware TRELLIS — [arXiv](https://arxiv.org/abs/2507.06165); its code derives from TRELLIS (MIT) and PartField (NVIDIA Source Code License) per its NOTICE — [OmniPart HF NOTICE](https://huggingface.co/spaces/omnipart/OmniPart/blob/main/NOTICE)
- HoloPart: 3D part amodal segmentation, a diffusion model that completes hidden parts of segmented pieces — [summarised in OmniPart/PartCrafter papers](https://arxiv.org/pdf/2506.05573)
- PartPacker (NVIDIA, 11 June 2025, NeurIPS 2025): part-level objects from one image via "dual volume packing"; NVIDIA Non-Commercial License — [Hugging Face](https://huggingface.co/nvidia/PartPacker), [cgworld.jp](https://cgworld.jp/flashnews/01-202506-NVIDIA-PartPacker.html)
- MMPart (arXiv 2509.16768) uses a multimodal LLM for single-image part-aware generation — [arXiv](https://arxiv.org/pdf/2509.16768v1)
- CSM was the one service known for breaking objects into separable parts, now unavailable — [Sloyd blog](https://sloyd.ai/blog/3d-ai-price-comparison), [StraySpark](https://www.strayspark.studio/blog/generative-3d-tools-comparison-meshy-rodin-tripo-csm-2026)

### Inferences
- For a sockets-based parts kit, the more reliable route is to generate each part on its own (a helmet alone, a sword
  alone, a horse body without rider) from its own concept image, then fit sockets by hand/code, rather than segmenting
  a whole "centaur legionary". Segmentation outputs are untextured (Tripo) or "light" (Hunyuan X-Part open), and cut
  lines won't match the game's socket layout.
- Rider vs mount separation is easiest by generating them separately; no source showed a generator that splits a
  rider from a mount cleanly.

### Gaps
- Licence files of PartCrafter, OmniPart, and Hunyuan3D-Part not read; Hunyuan3D-Part likely carries Tencent's
  territory-restricted licence (unverified inference).
- No quality evidence found for segmentation on creatures/characters specifically.

## 3. Creatures and quadrupeds (anatomy, legs, centaurs)

### Takeaway
No direct, sourced test of any 3D generator on centaurs or hybrid anatomy was found. Rigging tools support quadrupeds
(Meshy), but sources say auto-rigging breaks on unusual shapes, and known failure modes are fused or miscounted legs.

### Cited Findings
- Meshy auto-rigging handles humanoid and quadruped characters (detects body plan: humanoid, quadruped, or smart-rig), not props/vehicles; export FBX, Mixamo-compatible — [Meshy rigging docs](https://docs.meshy.ai/webapp/guides/3d-model/rigging), [Meshy feature page](https://www.meshy.ai/features/ai-auto-rigging)
- Auto-rigging "works on clean humanoid meshes and falls apart on anything unusual"; four-legged creatures, multi-armed bosses, mechs "often need hand rigging" (vendor blog, June 2026) — [Summer Engine](https://www.summerengine.com/blog/ai-3d-game-asset-generator)
- Legs welded together (blocking rigging) listed as a common failure in generated horse models (vendor blog) — [Neural4D](https://blog.neural4d.com/image-to-3d/3d-horse-model-generator/)
- Research on 3D animal reconstruction from web images notes left/right leg confusion from side views — [3D Fauna, arXiv 2401.02400](https://arxiv.org/pdf/2401.02400)
- Image generators repeatedly fail to draw a centaur with human torso and four horse legs (2D, ChatGPT) — [Underground Designs](https://undergrounddesigns.substack.com/p/why-cant-chatgpt-draw-a-centaur)

### Inferences
- In an image-first pipeline, the concept image is the bottleneck for centaurs: if the image is wrong, image-to-3D
  will faithfully reproduce the wrong anatomy. Since the game composes centaurs from a horse body + a human torso on
  sockets, generating the parts separately sidesteps the hybrid problem entirely.
- Legs: for the game's keyed-leg bakes, legs fused to the body would need cutting at the hips anyway; expect to
  separate legs by hand or via segmentation.

### Gaps
- No published side-by-side of Meshy/Tripo/Rodin/TRELLIS.2 on animals (rats, frogs, bears, elephants, horses). A small
  in-house test set is the only way to answer this.

## 4. Style consistency across hundreds of assets

### Takeaway
No generator offers a true style LoRA for 3D; consistency comes from the input images. Multiview input (Tripo, Meshy)
and image-first pipelines (make all concept images in one style, then image-to-3D) are the practical levers, and
retexturing/rebaking afterwards. Every source agrees cross-asset consistency is still hard.

### Cited Findings
- Tripo H3.1 accepts multiview input (same price as single image) and exposes `model_seed` / `texture_seed` — [Tripo developer docs](https://developers.tripo3d.com/en/models/v3-1)
- Meshy API has Multi-Image to 3D (same price as single image) and Retexture (10–15 credits); Meshy also sells text-to-image / image-to-image (nano-banana family, GPT Image) inside the same API, 3–12 credits — [Meshy API pricing](https://docs.meshy.ai/api/pricing)
- TRELLIS.2 has a separate texturing pipeline for an existing mesh — [TRELLIS.2 GitHub](https://github.com/microsoft/TRELLIS.2)
- Hunyuan3D-Omni: controllable generation (extra conditioning signals) — [gittrend](https://gittrend.io/repo/Tencent-Hunyuan/Hunyuan3D-Omni)
- A vendor lists "maintaining a consistent art style across AI-generated assets" as a known challenge — [3D AI Studio](https://3daistudio.com/3d-generator-ai-comparison-alternatives-guide/can-i-use-ai-for-indie-game-assets); a mirrored subreddit thread recommends image generation for concepts, 3D generator for blockouts, then human finishing ("AI-assisted, not AI-owned") — [subreddit snapshot](https://reddit.sentinel-team.org/posts/1t5q2pj/snapshots/2026-05-08T22%3A27%3A28.91308Z)
- Vendors claim reference-image "style locking" across assets (unverified marketing) — [Tripo style guide](https://www.tripo3d.ai/game-development/style-guide-ai-3d-modeling-tools-for-game-assets)

### Inferences
- Because the game bakes its own sprites and recolours team regions with a mask shader, texture style can be imposed
  downstream: generate geometry (untextured is cheaper: Tripo 10–20 credits, Meshy mesh-only 20) and apply the game's
  own materials/palette at bake time. This makes geometry consistency (proportions, scale) the main problem, which
  the parts kit's sockets and scale normalisation already control.

### Gaps
- No sourced, measured study of style drift across a large batch. No first-hand r/gamedev or r/StableDiffusion threads retrieved directly.

## 5. Running locally on Apple Silicon vs cloud APIs (speed, price, limits)

### Takeaway
TRELLIS.2 runs on an M-series Mac through community ports (PyTorch MPS ~3.5 min per mesh on an M4 Pro 24 GB; MLX
ports in progress). Hunyuan3D 2.1 has MPS forks and an MLX shape-only port, but its licence excludes the UK/EU.
Cloud APIs cost roughly $0.20–$0.80 per model and allow ~10 parallel tasks (Tripo).

### Cited Findings
**Local (Apple Silicon)**
- Official TRELLIS.2: Linux only, NVIDIA GPU ≥24 GB, CUDA 12.4 — [TRELLIS.2 GitHub](https://github.com/microsoft/TRELLIS.2)
- trellis-mac (PyTorch MPS port, Shivam Kumar): ~400k vertices / 800k triangles with Metal-baked PBR textures; 24 GB+ unified memory recommended, peak ~18 GB; ~3.5 min per image on a 24 GB M4 Pro; first run downloads ~15 GB weights — [trellis-mac wiki](https://github.com/shivampkumar/trellis-mac/wiki), [Korben](https://korben.info/en/trellis-mac-microsoft-image-to-3d-apple-silicon.html), [Show HN](https://hn.svelte.dev/item/47828896)
- trellis2-mlx (native MLX backend): tested on 128 GB; lower memory "may work, especially at 512³" but not validated — [trellis2-mlx](https://github.com/gtrg55/trellis2-mlx/wiki); lyonsno/trellis2mlx: early stage, mesh decoder still missing — [lyonsno/trellis2mlx](https://github.com/lyonsno/trellis2mlx)
- Hunyuan3D 2.1 README claims macOS support (install uses CUDA builds); community MPS forks (Brainkeys/Hunyuan3D-2.1-mac, VladimirTalyzin/hunyuan3d-2.1-mac); an MLX port of Hunyuan3D-Shape reported at 2–5 min, under 2 min geometry on an M3 Max — [Hunyuan3D-2.1 GitHub](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1), [VladimirTalyzin README](https://raw.githubusercontent.com/VladimirTalyzin/hunyuan3d-2.1-mac/main/README.md), [Elite AI Advantage](https://eliteaiadvantage.com/blog/run-ai-3d-model-generation-locally-mac)
- ComfyUI on Mac uses the Apple GPU for Hunyuan3D; the Blender add-on uses CPU only (M2 Pro / M2 Air tests) — [Zenn](https://zenn.dev/renue/articles/144cd47fbe9d7a)

**Cloud APIs**
- Meshy API credits (Oct 2026): meshy-7.1/6 image-to-3D mesh-only 20, 2K/4K texture 30, 8K 35; meshy-6-lite 5 (mesh) / 15 (textured); Ultra geometry +5; Remesh 5; rigging 5. USD/credit and rate limits are on other pages — [Meshy API pricing](https://docs.meshy.ai/api/pricing)
- Meshy web plans: Pro $20/month = 1,000 credits ⇒ ~$0.40 per textured model (Sept 2025 comparison); Studio $60/seat/month — [Sloyd blog](https://sloyd.ai/blog/3d-ai-price-comparison), [StraySpark](https://www.strayspark.studio/blog/generative-3d-tools-comparison-meshy-rodin-tripo-csm-2026); Meshy Pro includes an official MCP server `@meshy-ai/meshy-mcp-server` — [StraySpark](https://www.strayspark.studio/blog/generative-3d-tools-comparison-meshy-rodin-tripo-csm-2026)
- Tripo H3.1 API credits: image-to-3D untextured 20, standard 30, detailed 40, 8K 50; text-to-3D 10/20/30/40; detailed geometry +20, quad +5, smart low-poly +10, parts +20; 10 parallel tasks (H series), varies by tier — [Tripo developer docs](https://developers.tripo3d.com/en/models/v3-1)
- Tripo API credits at $0.01 each (2024 announcement, possibly outdated) ⇒ ~$0.20–0.50 per model — [Tripo blog](https://www.tripo3d.ai/blog/announcement-tripo-openapi-platform-payment-system); third-party host Atlas Cloud lists Tripo H3.1 at $0.10/generation — [Atlas Cloud](https://www.atlascloud.ai/models/Tripo)
- Tripo web plans: Professional $15.90/month = 3,000 credits (Sept 2025) — [Sloyd blog](https://sloyd.ai/blog/3d-ai-price-comparison); other listings: $19.90/month Pro, Advanced $49.90/8,000 credits, Premium $139.90/25,000 — [costbench](https://www.costbench.com/software/ai-3d-generation/tripo-ai/), [toolradar](https://toolradar.com/tools/tripo-ai/pricing)
- Rodin: credits charged on download, not generation; Creator $30/month (30 credits), Business $120/month (208 credits); a high-density Gen-2 download ~40 credits (third-party) — [costbench](https://www.costbench.com/software/ai-3d-generation/rodin-hyper3d/); reseller EmpirioLabs: Gen-2 $0.80 per request — [EmpirioLabs](https://empiriolabs.ai/models/hyper3d-gen2); StraySpark lists Rodin $29–149/month — [StraySpark](https://www.strayspark.studio/blog/generative-3d-tools-comparison-meshy-rodin-tripo-csm-2026)
- Example indie budget (~300 assets): Meshy Pro two months ($40) + Rodin monthly ($29) + ~40 h cleanup, vs $8k–30k outsourced — [StraySpark](https://www.strayspark.studio/blog/generative-3d-tools-comparison-meshy-rodin-tripo-csm-2026)

### Inferences
- At the game's scale (a few hundred parts), cloud cost is trivial (~$50–$250 total even at several attempts per
  part); the real cost is curation and cleanup time. Local TRELLIS.2 on an M-series Mac (~3.5 min each, ≥24 GB) is
  viable for batch overnight runs and avoids per-model fees and terms, at lower polish than Rodin/Tripo top tiers.
- Both Meshy and Tripo APIs suit offline automation (scriptable, async tasks, parallelism); the parts kit's asset
  list could drive a batch script.

### Gaps
- Meshy and Rodin rate limits and Meshy USD-per-credit for API not retrieved; official Rodin API pricing not retrieved.
- No MPS/MLX numbers for SF3D/SPAR3D found.

## 6. Licences (UK/EU developer)

### Takeaway
Hunyuan3D's open-weight licence does not apply in the EU, UK or South Korea, so a UK developer has no licence to use
those weights (Tencent's cloud service is a separate contract). TRELLIS / TRELLIS.2 are MIT. SF3D/SPAR3D are free
under $1M annual revenue. PartPacker is non-commercial. Meshy and Tripo paid plans give the user ownership; free plans
are CC BY 4.0 (Meshy) or Tripo-retained / public.

### Cited Findings
- Tencent Hunyuan 3D 2.1 Community License: Territory = "the worldwide territory, excluding the territory of the European Union, United Kingdom and South Korea"; agreement "DOES NOT APPLY IN THE EUROPEAN UNION, UNITED KINGDOM AND SOUTH KOREA"; use outside Territory is "unlicensed and unauthorized" (s.5c); >1M MAU needs a separate Tencent licence (s.4); "Tencent claims no rights in Outputs You generate" (s.6d); acceptable-use policy with 20 restrictions — [Hunyuan3D-2.1 LICENSE](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/LICENSE)
- Tencent's own guidance: check each model's licence and the Tencent Cloud service terms separately before commercial use — [ToolNavs](https://toolnavs.com/en/article/823-hunyuan-3-d-engine-global-shang-xian-mian-xiang-quan-qiu-chuang-zuo-zhe-de-ai-3)
- TRELLIS.2: MIT for code and weights; dependencies nvdiffrast and nvdiffrec are under NVIDIA licences — [TRELLIS.2 GitHub](https://github.com/microsoft/TRELLIS.2)
- Stable Fast 3D / SPAR3D: Stability AI Community License, free for commercial use under US$1M annual revenue; enterprise licence above — [Stability membership](https://stability.ai/membership), [Hugging Face SF3D](https://huggingface.co/stabilityai/stable-fast-3d)
- PartPacker: NVIDIA Non-Commercial License — [Hugging Face](https://huggingface.co/nvidia/PartPacker)
- OmniPart code mixes MIT (TRELLIS) and NVIDIA Source Code License (PartField) components — [OmniPart NOTICE](https://huggingface.co/spaces/omnipart/OmniPart/blob/main/NOTICE)
- Meshy: free plan outputs CC BY 4.0 (commercial with attribution); paid (Pro+) private licence, full commercial use, user owns output; rights kept after downgrade; Meshy 6/7 models not downloadable on free plan — [Meshy pricing docs](https://docs.meshy.ai/en/webapp/pricing), [Meshy help](https://intercom.help/meshy/en/articles/16102098-can-i-use-meshy-assets-commercially), [Meshy help, free plan](https://intercom.help/meshy/en/articles/15696428-what-is-included-on-the-free-plan); ToS dated 7 Mar 2026 — [Meshy ToS](https://www.meshy.ai/cs/terms-of-use)
- Tripo: paid users hold all rights to inputs and outputs and Tripo will not train on them (ToS 5.2.2); for free users Tripo retains rights (ToS 5.2.1) — [Tripo help](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially); third-party blogs instead describe free outputs as public CC BY 4.0 — conflict, ToS itself not retrieved — [Tripo blog](https://www.tripo3d.ai/blog/commercial-use-ai-3d-models)
- Rodin: only third-party claim found that the free tier includes commercial rights — [costbench](https://costbench.com/software/ai-3d-generation/rodin-hyper3d/hidden-costs/)

### Inferences
- For a UK solo dev, the safe options are: TRELLIS.2 (MIT, local), Meshy or Tripo on a paid plan (ownership
  granted), Rodin after checking its ToS. Avoid Hunyuan3D open weights (and likely Hunyuan3D-Part / Omni, if under
  the same licence family) and PartPacker for shipped assets.
- Steam requires disclosure of AI-generated content in shipped games (not researched here; flag for the business notes).

### Gaps
- Rodin/Hyper3D official ToS and output ownership not retrieved.
- Licence texts for Hunyuan3D-Part, Hunyuan3D-Omni, PartCrafter, and the TRELLIS.2 Mac ports not read.
- Whether Tencent Cloud's Hunyuan3D API terms are available to UK/EU customers: not found.
