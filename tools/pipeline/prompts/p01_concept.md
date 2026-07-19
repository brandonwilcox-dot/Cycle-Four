# S1 — Concept lock (text → Rodin, no 2D pass)

You are running Stage S1 of the Cycle Four model pipeline. Params: {{PARAMS}}

1. Read `concept.faction_anchor`, `concept.unit_role_phrase`,
   `concept.variation_adjectives`, `concept.negative_terms` from the params.
2. Compose ONE Rodin/Hyper3D text-to-3D prompt (~40–80 words) combining them, in this
   order: subject (role phrase) → form language (faction anchor) → styling (variation
   adjectives) → material cues → negatives. Style target: clean game-asset sculpt,
   single object, neutral pose.
3. Constraints: it must describe a SINGLE cohesive object; no scene/environment words;
   author colors near-neutral if `mode` is B (Cosmetics color channels tint at runtime).
4. Show me the prompt with a one-line rationale per clause (Gate G1). Iterate on my
   feedback.
5. On approval: write it to `params.concept.prompt` AND `<wip_dir>/concept/prompt.txt`,
   set `gates.g1_concept` to today's date.
   `PIPELINE_RESULT: PASS — prompt locked`.
