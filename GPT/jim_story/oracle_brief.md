Step: `oracle_brief`
Recipe: `jim_story`
Script: `scripts/jim/oracle_brief.coffee`

Purpose:
- single MLX call to compose a structured narrative brief from the
  ingredient bundle
- the only stochastic step in the pipeline
- output feeds `writediary`'s KAG generator as its prompt material

Inputs:
- artifact `ingredient_bundle`
- step params (all live in `override/jim_story.yaml`):
  - `model`        — local MLX path, e.g. `build/model4`
  - `max_tokens`   — 800 is comfortable budget for the full structured response
  - `temp`         — 0.0 = greedy (identical runs); 0.7 = recommended variation
  - `top_p`        — 0.95 nucleus sampling
  - `seed`         — set integer for reproducible runs; unset for fresh each run

Outputs:
- artifact `diary_brief`:
  ```
  {
    brief:           <multi-paragraph narrative brief>,
    structure_hints: [ <one line per beat in order> ],   # length 5
    transitions:     [ <one line per beat pair> ],       # length 4
    motif_thread:    <one-paragraph description>,
    voice_target:    <one-line voice note>,
    motif:           <copied from bundle>,
    arc_shape:       <copied from bundle>
  }
  ```

Parse fallback: if extraction fails, `{ brief: <raw output>, parse_error: true, motif, arc_shape }`.

MLX wrapping:
- mlx_lm wraps generation with `==========\n...==========\n` framing
  and a trailing stats block (`Prompt: N tokens, Generation: N tokens,
  Peak memory: ...`). `stripMlxFraming` removes both before searching
  for JSON.

JSON extraction (`extractJSON`):
1. `stripMlxFraming` removes MLX framing.
2. `findBalancedJson` walks character-by-character tracking brace depth
   and string state. Finds the first balanced `{...}`. Reports
   `truncated: true` if it ran off the end without closing.
3. `JSON.parse` the balanced span.
4. On parse failure for a truncated span, `repairTruncatedJson` closes
   any open string, trims trailing partial keys / dangling commas, then
   appends closing brackets/braces in reverse stack order.

Sampling determinism:
- WITHOUT `temp` / `top_p` / `seed` mlx_lm defaults to greedy (temp 0)
  and identical inputs produce byte-identical output. Always set
  `temp > 0` in override unless you want regression-test stability.

Invariants:
- writes `diary_brief` to memo and (via runner) to `out/diary_brief.json`
- does NOT emit `story_id` (obsolete)
- meta-prompt requests JSON of an exact shape; relies on Qwen
  Instruct-tuned models to honor it

Known pitfalls:
- max_tokens 400 silently truncates the 5-field structured response;
  raise to 800.
- the meta-prompt is the main tuning knob. Watch for:
  - Qwen reflecting the prompt's "Ingredients" section back as the brief
    instead of composing new content
  - drift from the named characters/locations into invented proper nouns
    (the instructions warn against this; if it leaks, sharpen the instruction)
  - voice_target getting too generic (Qwen defaults to neutral); name
    Jim's specifics in the meta-prompt if needed
- the test harness `test/test_extract_json.coffee` replays the verbatim
  broken output from the user's first failing run; use it to verify
  changes to the extractor.
