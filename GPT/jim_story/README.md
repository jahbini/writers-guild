Step memories for the `jim_story` recipe — writers-guild's primary
pipeline.

Read [`library_schema.md`](library_schema.md) first. The library schema
is the editing surface curators interact with; every step downstream
either flattens it or reads what the flattener produced.

Pipeline graph:

```
load_library            → story_library
select_story_recipe     → story_recipe
resolve_story_parts     → story_parts
assemble_ingredients    → ingredient_bundle
oracle_brief            → diary_brief         (MLX call here)
[story_spine PLANNED]   → story_spine.json    (structural sidecar; see story_spine.md)
write_diary             → diary/<recipe>_HH_MM.yaml
```

The first four steps are deterministic. `oracle_brief` is the only
stochastic step today. `write_diary` reads artifacts from disk
rather than the memo to avoid wiring drift.

`story_spine` (planned) will emit a strictly-structural JSON plan
alongside `diary_brief`, validated against `schemas/story_spine.schema.json`.
See `story_spine.md` for the full design and locked decisions.

Conventions for this directory:
- recipe-flavor metadata (motif, arc_shape, voice_notes, characters_in_play,
  locations_in_play) lives in `data/jim_story_library.yaml`'s
  `recipe_defaults:` block, NOT a `stories:` map; the obsolete
  `story_id` concept has been removed everywhere
- runtime tuning (model, max-tokens, temp, top-p, seed) lives in a
  nested `mlx:` block under each MLX step in `override/jim_story.yaml`.
  Canonical CLI-flag names (dashes, not underscores). The ledger's
  `S.callMLX` auto-injects the block; step body passes only `{ prompt }`.
- `build/model4` is a symlink to real MLX weights hosted in the sibling
  `writediary` project (currently `writediary/pipes/diary/build/model4`).
  This repo does not ship model weights.
- the `motif` field in `assemble_ingredients` is now a **lens dropdown**
  backed by `story_atoms.lenses` (was UI_textarea). Field name kept as
  `motif` for backwards compatibility with the coffee scripts that read
  it. Lens options: `mind_worm`, `tarot_major_arcana`, `four_forces`,
  `i_ching_hexagram`.
- Steps use **sacred ledger style**: `action: (S) ->`, `S.need` (async
  — always `await`), `S.param`, `S.callMLX`, `S.make`, `S.done`. The
  legacy `M`/`getStepParam`/`saveThis` pattern is no longer used.
- structural recipe (steps, dependencies, UI directives) lives in
  `config/jim_story.yaml`
