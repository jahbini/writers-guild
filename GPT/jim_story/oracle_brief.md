Step: `oracle_brief`
Recipe: `jim_story`
Script: `scripts/jim/oracle_brief.coffee`

Purpose:
- single MLX call to compose a structured narrative brief from the
  ingredient bundle
- the only stochastic step in the pipeline
- output feeds `write_diary` and (planned) the `story_spine` sidecar

Style: sacred (in-process). Signature is `action: (S) ->` where `S` is
the ledger. The step is `async` implicitly (CoffeeScript emits `async`
when the body contains `await`).

Inputs:
- artifact `ingredient_bundle` — read via `await S.need 'ingredient_bundle'`.
  `S.need` returns a Promise; forgetting `await` produces `bundle.map is
  undefined` style errors because `bundle` is a Promise, not the object.

Runtime tuning (in `override/jim_story.yaml` under `oracle_brief.mlx:`):
```yaml
oracle_brief:
  mlx:
    model: build/model4      # symlink → /Users/jahbini/writediary/pipes/diary/build/model4
    max-tokens: 800          # canonical CLI flag name (dashes, not underscores)
    temp: 0.7                # 0 = greedy/deterministic; 0.7 = recommended variation
    top-p: 0.95
    # seed: 42               # set for reproducible test runs
```
The ledger's `S.callMLX 'generate', payload` auto-injects the mlx block —
the step body passes only `{ prompt }`. Do NOT read `model`/`max_tokens`/
`temp`/`top_p` via `S.param` from the step body; the runner handles it.

Model symlink:
- `build/model4` is a symlink to a locally-hosted quantized MLX model
  in the sibling `writediary` project. The writers-guild repo does not
  ship model weights.
- Current target: `/Users/jahbini/writediary/pipes/diary/build/model4`
  (Qwen family, ~4.4 GB, config.json + model.safetensors + tokenizer).
- Historical gotcha: an earlier symlink pointed at
  `/Users/jahbini/writediary/build/model4`, which is empty. The real
  model lives one level deeper under `pipes/diary/build/`.

Outputs:
- artifact `diary_brief` written with `S.make 'diary_brief', brief`:
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
- `S.done()` closes the step. Do NOT write `done:<stepName>` manually;
  the ledger owns that key.

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
- WITHOUT `temp` / `top-p` / `seed` mlx_lm defaults to greedy (temp 0)
  and identical inputs produce byte-identical output. Set `temp > 0` in
  the mlx block unless you want regression-test stability.

Invariants:
- writes `diary_brief` via `S.make` (declared in the recipe's `makes:`)
- input `ingredient_bundle` is declared in the recipe's `needs:` and
  the runner enforces the contract — reaching across the wiring throws
- does NOT emit `story_id` (obsolete)
- meta-prompt requests JSON of an exact shape; relies on Qwen
  Instruct-tuned models to honor it

Known pitfalls:
- forgetting `await` on `S.need` → downstream `.map is undefined` on
  Promise objects. Sacred `need` is async.
- `max_tokens` 400 silently truncates the 5-field structured response;
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

History (2026-07-30):
- Migrated from legacy Memo-style API (`action: (M, stepName) ->`,
  `M.getStepParam`, `M.callMLX`, `M.saveThis`) to sacred ledger style
  (`action: (S) ->`, `S.need`, `S.callMLX`, `S.make`, `S.done`).
- Flattened runtime params (`model:`, `max_tokens:`, `temp:`, `top_p:`)
  collapsed into a nested `mlx:` block per pipeline_runner.coffee §9.
- Model symlink repointed from empty `build/model4` to real weights
  under `writediary/pipes/diary/build/model4`.
