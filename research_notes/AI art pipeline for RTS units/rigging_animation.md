# Automatic rigging and animation of AI-generated / arbitrary character and creature meshes (as of Oct 2026)

Scope note: researched 2026-10-31 with about 20 search/fetch calls. Vendor pages (Tripo, Meshy) were read
directly. Research repos (UniRig, Puppeteer) were read on GitHub. Practitioner reports (Reddit, Polycount) were thin
in search: most "reviews" are vendor blogs or SEO comparison sites, flagged below.

## Auto-rigging: which tools handle quadrupeds and non-humanoids, skinning quality, scriptability

### Takeaway
For a scripted, headless pipeline with quadrupeds, the only turnkey option found is **Tripo's rigging API**: one call
per model, rig types biped/quadruped/hexapod/octopod/avian/serpentine/aquatic, ~30 s, 25 credits, GLB/FBX out. Meshy
has a rigging API too, but its documented rig types are humanoid, "Quadruped Dog" and a beta "Smart Rig" with no
animation. The open research riggers (UniRig, SkinTokens, Puppeteer/MagicArticulate) are MIT/Apache, scriptable and
category-agnostic, but CUDA-only, hard to install, and their output (especially skinning) still needs checking. The
humanoid tools (Mixamo, AccuRIG) are out for quadrupeds and have no API.

### Cited Findings
**Tripo (commercial API)**
- Rig types: biped (default), quadruped, hexapod, octopod, avian, serpentine, aquatic; v3.0 adds "others". Input GLB/FBX/OBJ/STL, output rigged GLB (default) or FBX; ~30 s; auto-rig 25 credits; a free "Rig Check" (`v3/animations/rig-check`) checks compatibility and recommends a rig type — [Tripo rig docs](https://developers.tripo3d.com/en/models/rig)
- Model versions: v1.0-20240301 (default, biped only, 90+ biped presets); v2.5-20260210 "for non-humanoid creatures" (bipeds not recommended); v3.0-20260909 recommended for humanoids, must be set explicitly. Skeleton spec `tripo` or `mixamo`, v3.0 adds `actorcore`, `unity`, `unreal`, `vrm` (biped only) — [Tripo rig docs](https://developers.tripo3d.com/en/models/rig)
- Concurrency limit: 10 parallel rig/animation tasks — [Tripo rig docs](https://developers.tripo3d.com/en/models/rig)
- Third-party wrappers resell it (inference.sh "Tripo Auto Rig", Scenario "Tripo Rigging v2.5" for quadrupeds) — [inference.sh](https://inference.sh/apps/tripo/tripo-rig); [Scenario](https://www.scenario.com/models/tripo-rigging-v25)

**Meshy**
- Web app rig types: Humanoid, "Quadruped Dog", and "Smart Rig (Beta)" for anything else (creature, robot, prop), which places no markers. Input Meshy model or uploaded FBX/OBJ/STL/glTF/GLB up to 100 MB; >300k faces must be remeshed first; best in T/A-pose with gaps between limbs and body — [Meshy rigging guide](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging)
- No custom skeletons (no facial bones, tail physics). Smart Rig exports GLB only and cannot use the animation library. Quadrupeds get only a walk; humanoids walk and run — [Meshy rigging guide](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging)
- Documented failure modes: markers outside the model; bones misplaced if not near T/A-pose; mesh clipping from dense or uneven topology; "poor limb deformation" when proportions differ greatly from a standard human — [Meshy rigging guide](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging)
- API exists: `POST /openapi/v1/rigging` then `POST /openapi/v1/animations` with `rig_task_id` + `action_id` (or `action_ids` array for several clips in one file); catalogue at `GET /openapi/v1/animations/library` — [Meshy animation library API](https://docs.meshy.ai/api/animation-library); [Comfy Router Meshy schema](https://docs.comfy.org/development/comfy-router/models/meshy/animations/code.md). Whether the API exposes quadruped/Smart Rig was not confirmed.

**UniRig (VAST + Tsinghua, SIGGRAPH 2025 / ACM TOG Aug 2025)**
- Two stages: an autoregressive (GPT-like) transformer predicts a skeleton from the mesh, then a bone-point cross-attention model predicts per-vertex skin weights. Aimed at "humans, animals, objects" — [UniRig GitHub](https://github.com/VAST-AI-Research/UniRig); [gittrend summary](https://gittrend.io/repo/VAST-AI-Research/UniRig)
- MIT licence. Released: skeleton + skinning code, a checkpoint trained on Articulation-XL2.0, Rig-XL/VRoid data, training code. Still "planned": full checkpoints trained on Rig-XL/VRoid that reproduce the paper — [UniRig GitHub](https://github.com/VAST-AI-Research/UniRig)
- Needs a CUDA GPU with ≥8 GB VRAM for inference; no Mac support mentioned; installs warn of `flash_attn`, `spconv`, `torch_scatter`, `torch_cluster` version trouble. Input OBJ/FBX/GLB/VRM, output skinned FBX, merge script to rigged GLB — [UniRig GitHub](https://github.com/VAST-AI-Research/UniRig)
- Authors' own warning: a poor skeleton (e.g. missing tail or wing bones) degrades the skinning; refine the skeleton first — [UniRig GitHub](https://github.com/VAST-AI-Research/UniRig)
- Already integrated as an option in QtMeshEditor 3.11.0 (Pinocchio is the default there) — [QtMeshEditor release](https://github.com/fernandotonon/QtMeshEditor/releases/tag/3.11.0)

**SkinTokens / TokenRig (UniRig's successor, arXiv 2602.04805, Feb 2026)**
- Skeleton and skinning in one autoregressive sequence using learned discrete skin tokens; claims 98–133% better skinning accuracy than prior state of the art and 17–22% better bone prediction. Checkpoints on Hugging Face (FSQ-CVAE + TokenRig transformer on a Qwen3-0.6B architecture, GRPO-refined); a ComfyUI node exists — [arXiv 2602.04805](https://www.arxiv.org/pdf/2602.04805); [HF SkinTokens mirror](https://app.alphaneural.io/assets/VAST-AI/SkinTokens); [ComfyUI node](https://comfy.icu/node/SkinTokensRig). (Relative-accuracy claims are the authors' own.)

**MagicArticulate (CVPR 2025) and Puppeteer (NeurIPS 2025 spotlight), NTU + ByteDance Seed**
- MagicArticulate: autoregressive skeleton generation; dataset Articulation-XL2.0 (48K+ rigged models filtered from Objaverse-XL) — [MagicArticulate mirror](https://www.gitlink.org.cn/mirrors/MagicArticulate); [Puppeteer arXiv 2508.10898](https://arxiv.org/html/2508.10898v1)
- Puppeteer: auto-regressive skeleton + attention-based skinning + a differentiable, video-guided animation optimiser; dataset grown to 59.4K rigged models incl. 11.4K diverse poses. Authors report RigNet often produces invalid skeletons — [Puppeteer arXiv](https://arxiv.org/html/2508.10898v1)
- Inference code and checkpoints released 2025-09-04; Apache-2.0; Python 3.10, PyTorch 2.1.1, CUDA 11.8; FBX export via `bpy==4.2.0` (added 2025-09-10); video-guided animation demo released; example mesh is a deer — [Puppeteer GitHub](https://github.com/Seed3D/Puppeteer)

**RigNet (SIGGRAPH 2020; older material)**
- Older learned rigger; Puppeteer's authors report it "often produces invalid skeletons" compared with newer methods — [Puppeteer arXiv](https://arxiv.org/html/2508.10898v1). Superseded; not worth adopting in 2026.

**Anything World ("Animate Anything")**
- Launched Oct 2023; rigs and animates uploaded static models; Unreal listing claims quadrupeds and ungulates; Blender add-on calls a cloud backend (Replicate). No public API docs found — [The Next Web, 2023](https://thenextweb.com/news/anything-world-launches-ai-3d-animation-tool); [Fab listing](https://www.fab.com/listings/0d4c0a2c-8c97-4f2c-a659-864117af383a?lang=es-mx); [Blender extensions queue](https://extensions.blender.org/approval-queue/animateanything); [Anything World blog](https://anything.world/blog/rigged-ready-to-rumble)

**Mixamo, AccuRIG**
- Mixamo: biped only; Adobe's support docs (as quoted) exclude quadrupeds and characters with extra limbs, wings, tails; no API — [Tripo blog (competitor, quoting Adobe)](https://www.tripo3d.ai/blog/mixamo-alternative-that-can-rig-non-humanoid-or-quadruped)
- AccuRIG: free standalone Windows desktop app, humanoid-focused per most sources; a Tripo blog claims quadruped support (conflicting, competitor source); no API found — [Reallusion forum](https://discussions.reallusion.com/t/accurig-2-vs-mixamo-smarter-auto-rigging-for-3d-animators/14668); [cgdive AccuRIG page](https://cgdivetest.super.site/tools/accurig); contradicted by [Tripo blog](https://www.tripo3d.ai/blog/easiest-auto-rigging-tool)

**Blender-side (Rigify, Auto-Rig Pro, auto weights)**
- Blender's "automatic weights" (bone heat) fails ("Bone Heat Weighting: failed to find solution") on meshes with intersecting geometry, flipped normals, very small scale or very dense topology; workarounds: merge doubles, fix normals, decimate, scale the scene up ×10 before parenting — [BlenderArtists](https://blenderartists.org/t/bone-heat-weighting-failed/1240324); [Blender manual, Rigify basics](https://docs.blender.org/manual/fi/3.6/addons/rigging/rigify/basics.html)
- Voxel Heat Diffuse Skinning (paid add-on) voxelises non-watertight, multi-part characters into a solid so heat diffuses through; reviews mixed, elbows still need cleanup — [Superhive listing](https://superhivemarket.com/products/voxel-heat-diffuse-skinning)
- Auto-Rig Pro: rigs bipeds and quadrupeds, presets include dog and horse; a paid rig library adds 24 animal presets; a paid horse animation pack exists. No documented Python automation API found — [BlenderArtists ARP thread](https://blenderartists.org/t/auto-rig-pro-3-72/672834); [BlenderNation rig library](https://www.blendernation.com/2023/04/30/auto-rig-pro-rig-library-24-rig-presets-for-all-animals-big-and-small/); [ARP horse pack](https://blendermarket.com/products/arp--horse-animations-pack/faq)
- Epic's "Robust Skin Weights Transfer via Weight Inpainting" (SIGGRAPH Asia 2023) copies weights only where source and target confidently match, then inpaints the rest; aimed at garments/armour on different geometry — [paper preprint](https://www.dgp.toronto.edu/~rinat/projects/RobustSkinWeightsTransfer/preprint.pdf)

### Inferences
- For this game the creature set is known and small (horse, elephant, bear, centaur, humanoids of various builds). A **template-skeleton approach** fits better than predicting a fresh skeleton per mesh: one hand-made (or Rigify/ARP-made) armature per body plan, fitted to each generated mesh, then skinned. The ML riggers predict arbitrary topologies, which makes animation reuse across units harder.
- If meshes are generated in code (as the game does now), skinning can be computed exactly, with no ML: each primitive already knows which bone it belongs to; only the blend zones at joints need weights (e.g. by distance to the bone segments, or by voxel heat). This avoids the main ML failure modes.
- Tripo v2.5/v3.0 is the most plausible cloud fallback for "arbitrary AI mesh to quadruped rig". Its skeleton naming for non-biped types is not documented, which matters for reusing one animation set across many creatures.
- Centaurs are a non-standard body plan: none of the sources lists a centaur rig type. Tripo's v3.0 "others" type or a custom template is the likely route.

### Gaps
- No independent, quantitative comparison of skinning quality (Tripo vs Meshy vs UniRig vs SkinTokens vs Puppeteer) on quadrupeds was found.
- Tripo's quadruped skeleton bone names/topology were not documented on the pages read.
- Whether UniRig's "planned" full checkpoints have since shipped: the README status may be stale.
- Meshy API support for quadruped or Smart Rig: not confirmed.
- Auto-Rig Pro scripting: no official docs found on driving it headless (it is an operator-based add-on, so `bpy.ops` calls may work, unverified).

## Animation: motion libraries, text-to-motion, retargeting to non-humanoids, procedural gaits

### Takeaway
Commercial preset libraries are thin for quadrupeds (Tripo: 16 "universal" presets on v2.5/v3.0 rigs vs 90+ biped;
Meshy: one quadruped walk). Text-to-motion research for animals exists (AniMo, CVPR 2025; Kirin/AiM3D 2026) but is
research code tied to specific skeletons. For an RTS with a handful of cycles per body plan (walk, attack, work, die,
idle), procedural or hand-keyed cycles on a template rig, baked by script, are the practical route. No source covered
centaur gaits.

### Cited Findings
- Tripo animation API: 100+ presets total, 90+ biped-only; v2.5 and v3.0 rigs share 16 "universal" presets with IDs like `preset:quadruped:walk`; 10 credits per animation, batch up to 5 presets; `animate_in_place` strips root motion; GLB/FBX out; ~5 s — [Tripo animation docs](https://developers.tripo3d.com/en/models/animation)
- Meshy: humanoids get walk and run; quadrupeds a walk; Smart Rig models get nothing from the library — [Meshy rigging guide](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging); animation library catalogue (e.g. action 92 "Double Combo Attack", humanoid) — [Meshy animation library](https://docs.meshy.ai/api/animation-library)
- AniMo (CVPR 2025): species-aware text-to-motion for animals; AniMo4D dataset of 78,149 sequences and 185,435 descriptions across 114 species; also evaluated on AnimalML3D — [CVPR 2025 paper](https://openaccess.thecvf.com/content/CVPR2025/html/Wang_AniMo_Species-Aware_Model_for_Text-Driven_Animal_Motion_Generation_CVPR_2025_paper.html)
- Kirin / AiM3D (2026): animal motion reconstructed from in-the-wild video, video-text-motion tuples for quadrupeds, plus a pipeline that rigs and animates 3D meshes — [HF papers](https://huggingface.co/papers/2609.01823) (not verified beyond the listing)
- QuadFM (Mar 2026) notes earlier public quadruped datasets are small and mostly primitives (walk, trot, jump); it targets robot quadrupeds — [arXiv 2603.24021](https://arxiv.org/abs/2603.24021)
- Puppeteer animates a rigged mesh by optimising against a reference video (released code) — [Puppeteer GitHub](https://github.com/Seed3D/Puppeteer)
- Procedural Blender tools: Spider Walker (free, Python, Blender 5.2+, Aug 2026) plans foot steps per leg and bakes to an Action; IK Dynamic (paid) for multi-legged procedural locomotion; Auto Walk (2021, early) unfolds cycles along a curve; Free Walk (GPL) for Rigify bipeds; Mirror Animation (paid) mirrors L/R keys with a 50% phase offset for walk/trot/pace — [Digital Production](https://digitalproduction.com/2026/08/28/spider-walker-automates-multi-leg-animation/); [80.lv](https://80.lv/articles/free-blender-tool-for-procedural-spider-walks); [IK Dynamic](https://cgdivetest.super.site/tools/ik-dynamic); [Auto Walk](https://git.autourdeminuit.com/autour_de_minuit/auto_walk/src/commit/477646129b43bbcba7ede96aa8f8e30e30c44a72); [Free Walk for Rigify](https://blendermarket.com/products/free-walk-for-rigify); [Mirror Animation](https://www.getly.store/product/mirror-animation-smart-l-r-keyframe-mirroring-for-blender)
- Auto-Rig Pro sells a horse animation pack for its horse preset — [ARP horse pack](https://blendermarket.com/products/arp--horse-animations-pack/faq)

### Inferences
- The game already keys legs per step in code (D-179). A quadruped gait is a phase table per leg (walk: four-beat, legs ~25% apart; trot: diagonal pairs) plus IK foot placement; that maps directly to a template skeleton and needs no ML.
- A centaur is a quadruped gait on the lower body plus a humanoid upper body driven by the existing biped attack/work cycles, layered on the same skeleton. No source covered this; it is inferred from standard layered animation.
- Text-to-motion for humans (MDM, MotionGPT and successors) outputs SMPL-style human skeletons; retargeting to stylised short-legged or heavy bodies needs a retarget step. These were not researched in depth here; their value is low for a few short cycles per unit.

### Gaps
- No source on centaur rigs or gaits from any tool.
- No 2025-2026 practitioner reports on retargeting quadruped presets across differently proportioned creatures (horse vs elephant vs bear).
- Did not verify the current state of MDM/MotionGPT successors (2026) for humans.

## Skinned single mesh versus separate parts: keeping swappable gear

### Takeaway
The standard game practice is a hybrid: deforming gear (body armour, clothing) is skinned to the **same skeleton** as
the body; rigid gear (weapons, shields, helmets) is **parented to a bone or socket** with an offset. Engines drive
the gear meshes from the body's pose (Unreal's Leader Pose Component). Epic's weight-inpainting method addresses
transferring body weights onto armour of different shape.

### Cited Findings
- Armour pieces rigged to the same skeleton as the base body, swapped onto it, rather than keeping a full model per armour set — [Unreal Answers](https://answers.unrealengine.com/questions/855600/view.html)
- Unreal: armour as Skeletal Mesh Components with the body as Leader Pose Component (older: Set Master Pose Component) — [Unreal forums, modular goblin](https://forums.unrealengine.com/t/unicornway-stylized-modular-goblin-rogue/2841995); [Unreal Answers](https://answers.unrealengine.com/questions/855600/view.html)
- Rigid items (helmets, shields, weapons) parented to a bone with an offset; chest armour skinned to the skeleton so it deforms and doesn't clip into the arms — [Babylon.js forum](https://forum.babylonjs.com/t/clothing-armour-adding-visual-armour-to-3d-animated-characters/2143)
- Weapons skinned to dedicated bones under the hands so they can be hidden or swapped; standard bone naming eases swapping and retargeting — [Unreal forums, modular goblin](https://forums.unrealengine.com/t/unicornway-stylized-modular-goblin-rogue/2841995)
- Weight transfer onto garments/armour via confident-match copy plus inpainting — [Epic, SIGGRAPH Asia 2023](https://www.dgp.toronto.edu/~rinat/projects/RobustSkinWeightsTransfer/preprint.pdf)

### Inferences
- For this pipeline: weapon, shield and helmet stay as separate parts on sockets, now attached to **bones** (hand, head) of the skinned body so they follow it exactly. Worn armour either copies the nearest body weights (close-fitting plates) or is rigid per bone (pauldrons, greaves). Since the game bakes sprites offline, armour "skinned" by copying the body's weights per vertex is cheap and avoids runtime cost.
- The current detached-hand / floating-part bugs come from limbs being separate rigid parts. A single skinned body removes those seams; gear stays modular.

### Gaps
- No primary source found on the 2D-baked-sprite variant (offline bakes), though the principle is the same.

## Real reports from developers (2025-2026): failure modes and cleanup

### Takeaway
Reliable first-hand reports were scarce in search; most "reviews" are vendor or SEO pages. Consistent themes: AI
auto-rigs need joint and weight cleanup, they are tuned to near-human proportions, stylised or chunky characters
need manual correction, and the quality of the base mesh dominates.

### Cited Findings
- Tester: auto-rigging on Tripo H3.1 output "consistently fails at the joints", blamed on the base mesh — [Neural4D review of Tripo 3.1](https://blog.neural4d.com/comparisons/tripo-3-1-model-review/) (competitor blog)
- Auto-rig tuned for roughly human proportions; chunky/stylised characters often need manual correction — [3D AI Studio guide, Dec 2025](https://www.3daistudio.com/3d-generator-ai-comparison-alternatives-guide/best-3d-generation-tools-2026/10-ai-3d-tools-game-devs-playable-assets-2026) (SEO comparison site)
- Meshy rigging described as "very basic" by reviewers, no facial rigs — [vantaige Meshy page](https://vantaige.io/ai-tool/meshy-ai) (aggregator)
- Meshy's own docs list "poor limb deformation" for non-human proportions and clipping on dense meshes — [Meshy rigging guide](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging)
- UniRig authors: missing tail or wing bones degrade skinning — [UniRig GitHub](https://github.com/VAST-AI-Research/UniRig)
- A Polycount thread asks how people clean AI meshes before engine handoff (replies not retrieved) — [Polycount](https://polycount.com/discussion/comment/2809114/)

### Inferences
- The game's exaggerated proportions (heroic 5.5-head humans, rats, frogs, bears) are exactly where vendors say auto-rigging degrades. Combined with an automated "placement check" style test (feet on ground, hands on weapons), any auto-rig needs numeric validation per unit before baking.

### Gaps
- No primary Reddit/r/gamedev threads were retrieved; no quantitative cleanup-time figures found.

## What runs locally on Apple Silicon versus needing CUDA or the cloud

### Takeaway
Blender-side work (armatures, Rigify, automatic weights, procedural keying, baking) runs locally on macOS. The ML
riggers (UniRig, SkinTokens, Puppeteer) are documented for CUDA only, with custom CUDA extensions; no Mac support found.
Tripo and Meshy are cloud APIs.

### Cited Findings
- UniRig needs a CUDA GPU with ≥8 GB VRAM; deps include `flash_attn`, `spconv`, `torch_scatter`, `torch_cluster`; no Mac mentioned — [UniRig GitHub](https://github.com/VAST-AI-Research/UniRig)
- Puppeteer: CUDA 11.8, PyTorch 2.1.1 — [Puppeteer GitHub](https://github.com/Seed3D/Puppeteer)
- PyTorch MPS on Apple Silicon is experimental, some ops missing (`PYTORCH_ENABLE_MPS_FALLBACK=1` falls back to CPU) — [Hugging Face docs](https://huggingface.co/docs/transformers/main/perf_train_special); [Lightning MPS docs](https://lightning.ai/docs/pytorch/LTS/accelerators/mps_basic.html)
- No source found reporting UniRig, Puppeteer or MagicArticulate on Apple Silicon (search came back empty).
- Tripo and Meshy rig/animate as cloud APIs — [Tripo rig docs](https://developers.tripo3d.com/en/models/rig); [Meshy animation API](https://docs.meshy.ai/api/animation-library)
- Anything World's Blender add-on processes in the cloud — [Blender extensions queue](https://extensions.blender.org/approval-queue/animateanything)

### Inferences
- `spconv`, `flash_attn` and `torch_scatter`-style CUDA extensions make an MPS port of UniRig non-trivial; a rented CUDA box or the vendor APIs are the realistic routes for ML rigging.
- SkinTokens' transformer is a small Qwen3-0.6B architecture, which might run on MPS, but its other parts were not checked.

### Gaps
- No tested reports of any learned rigger on Apple Silicon.
