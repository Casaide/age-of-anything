# Licensing, disclosure and automated art QA for an AI-assisted RTS art pipeline (as of Oct 2026)

Context: UK-based solo developer, classic-style 2D isometric RTS on Steam (Early Access planned). Units are 3D models (built in code / Blender) baked to pixel sprites in 8 facings. Existing numeric placement checks cover ground contact, attachment, interpenetration and layering. Problems that still slip through: lumps on a bear's neck, detached hands, a centaur missing hind legs, blobby sphere-built bodies. Claude (vision-capable) develops the game.

Research note: 16 searches/fetches were made. Many licensing findings come from secondary blogs (some written by competing vendors); primary licence texts were reached only for Hunyuan3D (mirrors), PixelLab, Scenario and Stability. Verify every vendor term against the live page before shipping.

## Q1. Steam's AI disclosure rules and player reaction

### Takeaway
Steam labels rather than bans AI content. Since Valve's 2024 Content Survey, developers disclose "pre-generated" (made in development, shipped as static assets) and "live-generated" (made at runtime) AI content; a January 16, 2026 revision narrowed the focus to player-facing content and exempted AI dev tools (coding assistants, pipeline tools). For this game, AI-generated or AI-assisted unit art that ships counts as pre-generated and must be disclosed; Claude writing code does not. Disclosure correlates with notably fewer reviews and more AI-related criticism, with visual art the top complaint.

### Cited Findings
- Valve's original policy (January 2024): new Content Survey section on AI; two categories, pre-generated (created with AI tools during development) and live-generated (created while the game runs); developers must promise pre-generated content is not illegal/infringing and describe guardrails for live content; disclosures shown on the store page; players can report illegal AI content via the overlay — [Steam announcement, Jan 2024](https://store.steampowered.com/news/group/4145017/view/3862463747997849618) (URL from prior knowledge, not re-fetched this session).
- Valve revised the disclosure form on January 16, 2026, narrowing disclosure to AI content players see or hear and exempting internal development tools such as code assistants — [tbreak](https://tbreak.com/steam-ai-disclosure-policy-update-developers/); [StraySpark guide](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide); [papogames](https://papogames.com/en/blog/steam-ai-disclosure-2026) (all secondary).
- StraySpark quotes the revised form: "Efficiency gains through the use of these tools is not the focus of this section." It lists as exempt: AI coding assistants, editor automation (incl. MCP servers), build/pipeline tools, non-AI procedural generation. AI output players directly experience (e.g. AI textures) is not exempt — [StraySpark](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide) (secondary; StraySpark sells AI/MCP tools).
- Grey areas per StraySpark: AI upscaling of human-made textures (guidance points to disclosing as pre-generated), AI mocap/animation cleanup (most treat as exempt or pre-generated), placeholder AI content that ships (must disclose). Advice: disclose when uncertain — [StraySpark](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide).
- Live-generated disclosure requires models used, guardrails/filtering, types of content generated live; may add review cycles — [StraySpark](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide).
- Over 7,300 Steam games had disclosed AI content as of March 2026 — [StraySpark](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide); one source says ~20% of games now disclose — [tech-insider](https://tech-insider.org/steam-ai-disclosure-2026/) (headline claim, not verified).
- Unverified/conflicting: a claimed June 2026 update requiring AI metadata tags for every asset type including code; not corroborated and conflicts with the player-facing framing — [moexplains](https://moexplains.com/steam-ai-disclosure-rules-2026-update/) (search summary attributing it to Remio.ai).
- On October 23, 2026 Epic's Tim Sweeney called the disclosure requirement "abhorrent" — [tech-insider](https://tech-insider.org/steam-ai-disclosure-sweeney-abhorrent-epic-launcher-5-47s-2026/). No sign Valve has changed course.
- Player reaction, Game Oracle (Ross Burton, June 2026): 9,879 Steam games released Jan–Oct 2025; AI-disclosing games got ~53% fewer reviews than comparable games (reviews as sales proxy); median positive 84.6% vs 88.3%; effect stronger for large studios — [TechPowerUp](https://www.techpowerup.com/350230/games-made-with-gen-ai-suffer-up-to-53-worse-sales-on-steam); [Notebookcheck](https://www.notebookcheck.net/Study-suggests-AI-is-hurting-video-game-sales.1328725.0.html). Observational, not causal.
- Academic study (arXiv, Oct 2026): AI-disclosing games show more AI-related criticism in negative reviews than comparable games — [arXiv 2610.30178](https://arxiv.org/html/2610.30178v1).
- GameDevAIHub (Oct 2026), 352,296 English reviews: on games known to use AI, 78.9% of reviews that mention AI are negative (vs 23.1% negative across all reviews of those games); visual art is the most common complaint among negative AI-mentioning reviews (49.1%) — [GameDevAIHub](https://gamedevaihub.com/will-players-punish-ai-art-in-games/).
- GameDiscoverCo player survey: ~43% no big issue, ~26% neutral, ~31% negative about AI in games; 89% check or glance at AI labels — [XDA](https://www.xda-developers.com/dislike-ai-content-in-your-games-68-of-steam-users-disagree-with-you-says-survey/).
- Quantic Foundry "85% negative sentiment" figure is cited by StraySpark without explaining what it measures — [StraySpark](https://www.strayspark.studio/blog/steam-ai-disclosure-rules-2026-indie-developer-guide) (unclear; don't rely on it).

### Inferences
- Units built in code by Claude (procedural models in Lobster) are arguably "AI dev tools" output rather than generative-model output, but the result is player-facing art made with AI assistance. The conservative reading of the guidance (disclose when uncertain; Valve has reportedly removed pages for inaccurate disclosure) is to disclose as pre-generated, describing how (e.g. "unit models are built in code with AI coding assistance and checked by hand"). The honest, specific wording also suits the developer's "public copy" preference.
- The game's runtime race generator is deterministic and rule-based (no generative model at runtime), so it is not live-generated AI under either the 2024 or 2026 wording; non-AI procedural generation is explicitly exempt. If an on-device LLM prompt expander ships later (backlog item), that would become live-generated and need the fuller disclosure.
- Art is the most-criticised AI category, so if generative 3D/image tools are used, visible quality (the "looks wrong" problem) is the main reputational risk.

### Gaps
- Could not fetch the Steamworks documentation page for the January 2026 form text; tier details come from secondary blogs. Check the current Steamworks Content Survey before filling it in.
- No evidence on whether Valve has enforced page removals (claim is unsourced in StraySpark).
- No data specific to RTS players or Early Access titles.

## Q2. Output ownership and commercial terms: Meshy, Tripo, Rodin, PixelLab, Scenario, open models

### Takeaway
Paid plans of the commercial tools all grant commercial use; free tiers differ (Meshy free = CC BY 4.0 with attribution; Tripo free = non-commercial; Rodin free unclear; Scenario free = personal/evaluation). Among open models, Hunyuan3D 2.0/2.1 licences explicitly do not apply in the UK, EU or South Korea, so a UK developer has no licence to use them. TRELLIS/TRELLIS.2 are MIT (watch the non-commercial RMBG-2.0 dependency). FLUX.2 [klein] 4B is Apache 2.0; 9B is non-commercial. Stability's Community Licence allows commercial use under $1M annual revenue.

### Cited Findings
- **Meshy**: free-plan outputs licensed CC BY 4.0 (commercial use allowed with credit to Meshy); private ownership needs a paid plan — [cinevva guide](https://app.cinevva.com/guides/ai-3d-model-generators); [Tripo's own blog on Meshy terms](https://www.tripo3d.ai/blog/meshy-capabilities-and-commercial-terms) (competitor source). 
- **Tripo**: free-tier models public and non-commercial; terms quoted as "For Users who access and use the Services free of charge ("Free Users"), Tripo retains all rights"; commercial rights and private models on paid plans (e.g. Pro ~$19.90/mo) — [AssetForgeIndex](https://assetforgeindex.com/guides/tripo-commercial-use).
- **Rodin (Hyper3D/Deemos)**: free-plan commercial rights unclear/undocumented; paid Creator plan described as "unlimited export and any use" — [quickmatch.si](https://quickmatch.si/guides/meshy-vs-tripo/); [triposr.org](https://triposr.org/blog/free-online-image-to-3d) (secondary).
- **PixelLab (pixellab.ai)**: users retain ownership of content created; commercial and non-commercial use permitted; section 1.2 bars training your own models on generated images without written consent — [PixelLab ToS](https://www.pixellab.ai/termsofservice). Several unrelated "PixelLab" companies exist; only pixellab.ai is the pixel-art tool.
- **Scenario**: terms assign "all right, title, and interest in the Generated Assets" to the user, subject to Section 4.5 (AI Output Limitations, text not retrieved) — [Scenario T&C](https://www.scenario.com/terms-and-conditions); FAQ says generations from Scenario's public foundation/platform models are cleared for commercial use — [Scenario FAQ](https://help.scenario.com/articles/1129045411-frequently-asked-questions-faq); pricing page says free-plan outputs are personal/evaluation only — [Scenario pricing](https://www.scenario.com/pricing).
- **Hunyuan3D 2.0**: licence "Territory" = worldwide excluding the European Union, United Kingdom and South Korea — [Hugging Face LICENSE](https://huggingface.co/tencent/Hunyuan3D-2/blob/main/LICENSE); [ScanCode LicenseDB](https://scancode-licensedb.aboutcode.org/tencent-hunyuan-3d-2.0-cla.html).
- **Hunyuan3D 2.1** (licence dated June 13, 2025): states it does not apply in the EU, UK and South Korea; bars using outputs to improve other AI models — [licence mirror](https://gitserver.onethingai.com/ai-models/Hunyuan3D-2.1/raw/branch/main/LICENSE). Hunyuan3D-Omni reportedly carries the same exclusions — [DeepWiki](https://deepwiki.com/Tencent-Hunyuan/Hunyuan3D-Omni/6.1-licensing-and-legal) (secondary).
- **TRELLIS.2** (Microsoft, Dec 2025): MIT; no revenue cap, field-of-use limit or attribution requirement; but the official pipeline uses RMBG-2.0 for background removal, which is CC BY-NC 4.0 (non-commercial) — supply pre-cut images to avoid it — [3daistudio](https://www.3daistudio.com/blog/is-trellis-2-free-pricing-how-to-get-started); [trellis2.app](https://trellis2.app/blog/trellis-2-vs-hunyuan-3d) (secondary).
- **FLUX.2 [klein]**: 4B (and 4B Base) Apache 2.0, outputs usable commercially; 9B under FLUX non-commercial licence — [HF model card](https://huggingface.co/black-forest-labs/FLUX.2-klein-4B); [BFL blog](https://bfl.ai/blog/flux2-klein-towards-interactive-visual-intelligence).
- **FLUX.1 [dev]**: sources conflict. One quotes the licence as allowing Output "for any purpose (including for commercial purposes)" but forbidding use of outputs to train competing models — [topuseai](https://www.topuseai.com/blog/ai-image-commercial-licences); another says using it for commercial deliverables without a paid BFL licence is a violation — [digitalapplied](https://www.digitalapplied.com/blog/local-image-generation-flux-stable-diffusion-comfyui-2026). Likely both: outputs clause is permissive, but running the model for commercial purposes is not.
- **Stability AI Community Licence**: free research, non-commercial and commercial use for individuals/organisations under $1M annual revenue (from any source); above that an enterprise licence is needed — [Stability licence page](https://stability.ai/license). Reported registration requirement and "Powered by Stability AI" attribution — [Krea](https://www.krea.ai/blog/is-stable-diffusion-free-where-to-get-it-and-what-it-costs-in-2026) (secondary).

### Inferences
- For a UK developer: Hunyuan3D models are off-limits (no licence grant in the UK, regardless of revenue), including via third-party hosted APIs that run them unless that host has its own agreement with Tencent. TRELLIS.2 (MIT) is the cleanest open 3D option.
- Use only paid tiers of Meshy/Tripo/Rodin/Scenario for shipped assets; free-tier outputs are either attribution-bound (Meshy), non-commercial (Tripo, Scenario), or uncertain (Rodin). Keep a per-asset provenance log (tool, plan, date, licence snapshot), useful both for licences and for the Steam disclosure.
- Note many terms forbid using outputs to train other models (PixelLab, Hunyuan, FLUX dev) — irrelevant unless the developer fine-tunes on them.

### Gaps
- Did not read Meshy's, Tripo's or Rodin's own ToS pages directly; claims are from comparison blogs (two written by Tripo).
- Scenario Section 4.5 contents unknown.
- Unverified claim that Hunyuan3D licences require separate licensing above a user/revenue threshold (I recall a 1M monthly-active-users clause in 2.0 but did not confirm).
- Stability licence page metadata looked older; current threshold wording not re-confirmed.

## Q3. Copyright status of AI outputs (US and UK)

### Takeaway
US: purely AI-generated material is not copyrightable; prompts alone are not authorship; human selection, arrangement and modification can be protected. UK: s9(3) CDPA still nominally protects "computer-generated works", but the government's March 2026 report recommends removing it, with no legislation yet; AI-assisted human works remain protected. For this game, code-built models and human-directed composition are the stronger ownership position than prompt-generated assets.

### Cited Findings
- US Copyright Office, "Copyright and Artificial Intelligence, Part 2: Copyrightability", released January 29, 2025 — [copyright.gov NewsNet](https://www.copyright.gov/newsnet/2025/1060.html).
- Key line: "given current generally available technology, prompts alone do not provide sufficient human control to make users of an AI system the authors of the output"; repeated regeneration is "re-rolling the dice"; human-authored material perceptible in output, and creative selection, coordination or arrangement of AI output, can be protected; case-by-case analysis; >10,000 comments — [IPWatchdog](https://ipwatchdog.com/2025/01/29/part-two-copyright-office-ai-report-says-creative-prompting-doesnt-constitute-authorship/); [Copyright Alliance summary](https://copyrightalliance.org/ai-report-part-2-copyrightability/).
- UK: the government's Report on Copyright and AI (18 March 2026) concludes protection for computer-generated works under s9(3) CDPA should be removed (while monitoring), and that works created with AI assistance should stay protected; most respondents opposed protecting purely AI-made works — [GOV.UK report PDF](https://assets.publishing.service.gov.uk/media/69ba692226909a14239612e4/CP2602959_-_Report_on_Copyright_and_Artificial_Intelligence_web.pdf); [HSF Kramer](https://www.hsfkramer.com/notes/ip/2026-03/uk-government-report-on-copyright-and-ai-concludes-more-evidence-is-needed-although-s9-3-cdpa-could-go).
- Commentators describe the report as deferring decisions ("can-kicking"); as of mid-2026 no legislation imminent and the proposed text-and-data-mining commercial exception was dropped — [Simmons & Simmons](https://www.simmons-simmons.com/en/publications/cmn8tmopv0050ustoq2e6ndz2/a-masterclass-in-can-kicking-uk-government-views-on-ai-and-copyright); [Bird & Bird](https://www.twobirds.com/en/insights/2026/uk/copyright-,-a-,-aiin-the-uk-the-debate-rolls-on); [bratby.law](https://bratby.law/copyright-and-ai-training-exception-2026/).
- CREATe (June 2026) proposes a taxonomy of when prompted outputs might be protected in the UK — [CREATe blog](https://www.create.ac.uk/blog/2026/06/12/copyright-protection-of-prompted-generative-ai-outputs-in-the-united-kingdom-a-preliminary-taxonomy/).

### Inferences
- Steam sells worldwide, so the weaker US position matters: raw generator outputs may be copyable by others. Assets heavily composed, edited and assembled by a human (and the game as a whole, code, data, selection) remain protectable.
- Claude-written model code: the same human-authorship question applies, but the developer's direction, selection and editing likely give a protectable arrangement. Not legal advice.

### Gaps
- Exact dates of the UK consultation conflict across sources (Dec 2024–Feb 2025 vs a Feb 2026 close).
- No court ruling found specific to AI-generated game assets.

## Q4. VLMs as art critics (Claude/GPT/Gemini reviewing renders)

### Takeaway
VLM judges are useful but unreliable on exactly the errors this project has: counting (legs, limbs), distorted anatomy, and subtle attachment faults. Benchmarks show modest agreement with humans (GPTEval3D ~0.63 pairwise alignment per a later paper), strong yes-bias on yes/no questions, and a tendency to explain away distortions. Reliability improves with decomposed binary checklists, dependency-ordered questions, multi-view inputs, and fine-tuned or specialised evaluators. Use VLMs as a triage layer behind deterministic checks, not as the only gate.

### Cited Findings
- **GPTEval3D**: uses GPT-4V-class VLMs to compare text-to-3D assets pairwise over multiple criteria (text-asset alignment, 3D plausibility, texture-geometry coherence, etc.), aggregated into Elo; text-to-3D only — [emergentmind summary](https://www.emergentmind.com/topics/gpteval3d-benchmark); not applicable to image-to-3D — [3DGen-Bench paper](https://arxiv.org/abs/2503.21745).
- **3DGen-Bench** (2025): arena of human preferences, 1,020 prompts, 11,220 votes from public and expert annotators; trained 3DGen-Score (CLIP-based, cheap) and 3DGen-Eval (MLLM-based), reporting 3DGen-Eval matches or surpasses GPT-4V in human-preference alignment — [arXiv 2503.21745](https://arxiv.org/html/2503.21745v1); [GitHub](https://github.com/3DTopia/3DGen-Bench).
- **Hi3DEval** (NeurIPS 2025 D&B): hierarchical (object and part-level) 3D evaluation; reports GPTEval3D at about 0.63 pairwise alignment on text-to-3D, below its own model (authors' claim) — [Hi3DEval PDF](https://papers.neurips.cc/paper_files/paper/2025/file/42ffaddcc6edc9fb05ff9f9b49fca700-Paper-Datasets_and_Benchmarks_Track.pdf).
- T3Bench and GT23D-Bench are other text-to-3D benchmarks (multi-view scoring) — [GT23D-Bench](https://arxiv.org/pdf/2412.09997). (T3Bench details not retrieved.)
- **FineGRAIN** (arXiv 2512.02161): 27 failure modes for text-to-image; all tested generators scored very low on counting; anatomy accuracy ranged from ~7% to 53% (Flux); VLM judges often overlook distorted anatomy and sometimes rationalise it as an optical illusion — [FineGRAIN](https://arxiv.org/html/2512.02161v1).
- **HumanBench** (WACV 2026): "Two Heads, No Legs, But Mostly Human" — persistent missing/duplicated limbs and disfigurement in generated humans — [HumanBench](https://openaccess.thecvf.com/content/WACV2026/papers/Jain_HumanBench_Two_Heads_No_Legs_But_Mostly_Human_the_State_WACV_2026_paper.pdf).
- **Distortion-5K**: ~50% of images from four popular T2I models had body distortions; a specialised ViT detector localised distortions better than segmentation models and VLMs — [arXiv 2503.00811](https://arxiv.org/html/2503.00811v1).
- Counting: VLMs struggle with compositional counting — [VLMCountBench, arXiv 2510.04401](https://arxiv.org/pdf/2510.04401); failures attributed to enumeration binding under load — [arXiv 2511.17722](https://arxiv.org/html/2511.17722v1); Qwen models struggle with fine-grained counts such as animal legs — [arXiv 2509.08266](https://arxiv.org/pdf/2509.08266). "VLMs are biased": models answer from prior knowledge (e.g. "dogs have 4 legs") instead of looking — [vlmsarebiased.github.io](https://vlmsarebiased.github.io/) (page content partly unverifiable).
- Rubric techniques: binary checklist questions instead of Likert scores reduce rating variance across judges (CheckEval) — [EMNLP 2025](https://aclanthology.org/2025.emnlp-main.796.pdf); TIFA/DSG decompose prompts into verifiable questions, DSG uses a dependency graph so child questions are skipped when the parent fails ("is it red?" not asked if the object is absent) — [VisExMEM](https://arxiv.org/html/2610.16441v1); [Medium comparison](https://medium.com/@shujuanhuang/the-trinity-of-atomic-faithfulness-dsg-psg-and-soft-tifa-3c4557b12c5b); VLMs default to "yes" on yes/no questions, weaker judges more so — [Arena-T2I Hard](https://arxiv.org/html/2606.31711).

### Inferences (applied to this project)
- The VLM's priors are the problem: asked "does this centaur have four legs?", it will tend to say yes because centaurs do. Counter with open-ended counts ("list each leg you can see with its position") rather than confirmations, and ask before revealing what is expected; compare the answer to the count from `parts.json` in code.
- Make failures easier to see before asking: render diagnostic views, not just the final pixel sprite: a large (e.g. 512 px) unshaded render, a flat-colour per-part ID render (each part a distinct colour), a silhouette, and a turntable grid of the 8 facings. Ask per-part questions on the ID render ("is the right hand touching the right forearm?").
- Use dependency-ordered binary checks (DSG pattern): body present -> count legs -> each leg reaches ground -> each hand attached -> no protrusion on neck/back -> surface reads smooth not lumpy.
- Pairwise against an approved baseline ("A is the last approved bake, B is new: list visible differences") plays to VLM strengths better than absolute judgement; this also matches GPTEval3D's pairwise design. Direct evidence that pairwise beats absolute for VLM image judging was not found.
- Run each question 2-3 times or across facings and only flag on agreement; treat the VLM as a recall-oriented triage that produces a short list for human or numeric confirmation.

### Gaps
- No benchmark specific to stylised game sprites, pixel art or isometric renders.
- No published numbers for Claude specifically as a 3D-render judge.
- No direct evidence on pairwise vs absolute VLM scoring for images.

## Q5. Geometric mesh checks

### Takeaway
Cheap, deterministic geometry checks catch most of the listed failures if the expected structure is known from data: connected components (detached hands), per-part attachment distance, watertightness/non-manifold edges, limb counting by skeleton end-points (missing hind legs), and curvature/shape-roughness measures for "blobby spheres". Skeletonisation and Reeb graphs are established tools for counting protrusions; thresholds need tuning per body.

### Cited Findings
- trimesh: `is_watertight` checks each edge is shared by exactly two faces; `trimesh.graph.split` splits by face connectivity (default only watertight components; `only_watertight=False` keeps all) — [trimesh docs](https://trimesh.org/trimesh.html); [trimesh.graph](https://trimesh.org/trimesh.graph.html); watertightness can be fooled by overlapping edges / processing options — [trimesh issue #122](https://github.com/mikedh/trimesh/issues/122); [issue #2236](https://github.com/mikedh/trimesh/issues/2236).
- skeletor extracts curve skeletons from meshes, including by a Reeb graph of geodesic distance with level sets collapsed to centroids — [skeletor](https://github.com/navis-org/skeletor).
- Reeb graphs capture surface topology and protrusions, used for segmentation — [arXiv 2412.05335](https://arxiv.org/pdf/2412.05335); data skeletonisation via Reeb graphs — [Ge et al., NeurIPS 2011](http://papers.neurips.cc/paper/4375-data-skeletonization-via-reeb-graphs.pdf).
- Medial-axis / L1-medial skeletons can form spurious cycles when parts are close (e.g. legs close together) — [Skeletonization via Local Separators](https://arxiv.org/pdf/2007.03483).

### Inferences (applied)
- Because models are built in code from named parts, many checks can work on the part graph rather than raw mesh: assert every part's bounding volume touches or overlaps its socket parent within a tolerance (detached hand), and that the declared leg count (from `parts.json` legs/poses) equals the number of leg parts present and visible.
- On the merged mesh per facing/pose: count connected components (should be 1, or a known number for held weapons); skeletonise and count end-points below the torso's centre of mass and touching the ground plane to confirm leg count (centaur hind legs).
- Neck lumps: compare the union surface to the smooth hull locally, e.g. flag vertices whose distance outside a fitted body surface or convex-hull-of-neighbours exceeds a threshold; or check for small connected protrusions (a part whose volume mostly lies outside its parent but which is not a declared limb).
- Blobby spheres: measure how much of the silhouette contour is made of circular arcs or count concave "pinch" points between adjacent spheres; or compare silhouette to a reference silhouette (IoU) drawn from approved art.
- Symmetry: mirror the mesh across the body's sagittal plane and compute Hausdorff/Chamfer distance; large asymmetry outside declared asymmetric parts (`"cut": ["legs"]`) signals a missing or misplaced limb.
- In 2D, per facing: silhouette IoU against the previously approved bake; count connected opaque regions in the sprite alpha (a floating hand shows up as a separate island); count ground-contact columns of the silhouette bottom.

### Gaps
- No paper found giving accuracy numbers for automated limb counting on stylised game characters.
- No ready-made trimesh limb-counting function; would need building.

## Q6. Image metrics for style consistency and readability

### Takeaway
DreamSim (an ensemble of CLIP, OpenCLIP and DINO fine-tuned on human similarity judgments) agrees with human 2AFC judgments ~96% on its NIGHTS dataset versus ~94-95% for DINO or CLIP alone; use it (or DINO) to measure each new sprite's distance from approved reference art and flag outliers. These metrics measure overall similarity, not anatomical correctness, so they complement rather than replace structural checks.

### Cited Findings
- DreamSim concatenates CLIP, OpenCLIP and DINO embeddings and fine-tunes on ~20k human-judged triplets (NIGHTS); 2AFC agreement 96.2% (ensemble) vs 95.5% OpenCLIP, 94.6% DINO ViT-B/16, 93.9% CLIP ViT-B/32 — [DreamSim GitHub](https://github.com/ssnl/dreamsim); [NeurIPS 2023 paper](https://proceedings.neurips.cc/paper_files/paper/2023/file/9f09f316a3eaf59d9ced5ffaefe97e0f-Paper-Conference.pdf). A later PyPI table reports 96.9% ensemble / 95.6% DINO (different version/split) — [PyPI](https://pypi.org/project/dreamsim).
- Authors note DINO/CLIP capture high-level semantics but are not well aligned with finer-grained attributes; LPIPS/SSIM/PSNR sit at the low-level end — [DreamSim paper](https://proceedings.neurips.cc/paper_files/paper/2023/file/9f09f316a3eaf59d9ced5ffaefe97e0f-Paper-Conference.pdf).
- 3DGen-Score (CLIP-based) is the cheap scalable evaluator in 3DGen-Bench — [arXiv 2503.21745](https://arxiv.org/html/2503.21745v1).

### Inferences
- Embedding distance to a set of approved sprites (same unit, same facing) is a cheap regression alarm: a sudden jump means something changed visually. It won't say what.
- Silhouette readability at game size: downsample to in-game pixel size and check silhouette IoU/area against approved; check that distinct units remain distinguishable (pairwise embedding distance between unit types above a floor). No published metric for RTS readability was found.

### Gaps
- No source found on CSD (Contrastive Style Descriptors) or on DreamSim specifically for style consistency in game art.
- No evidence on how well these metrics work on very small pixel sprites (most training images are photographs or large renders).

## Q7. How studios set up automated art QA

### Takeaway
Little published detail was found on studio art-QA pipelines in this session. What is documented generally is content validation on import (naming, poly counts, texture sizes, manifoldness) plus human review; automated "looks wrong" detection in studios appears rare in public sources.

### Cited Findings
- No primary studio sources retrieved in this session.

### Inferences
- A layered gate fits this project: (1) existing numeric placement checks; (2) structural part-graph and mesh checks (component count, attachment, limb count vs data, symmetry); (3) 2D sprite checks per facing (alpha islands, silhouette IoU vs approved, DreamSim distance); (4) VLM checklist review of diagnostic renders, flagging only on repeated agreement; (5) golden-file regression so any visual change needs explicit approval. Each bug the human catches becomes a fixture, as the project already does for placement bugs.

### Gaps
- No GDC talks, studio blogs or tool docs on automated art QA were retrieved; a follow-up search (e.g. "GDC asset validation pipeline", "content validation art pipeline") is needed.
