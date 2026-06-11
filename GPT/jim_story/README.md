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
write_diary             → diary/<recipe>_HH_MM.yaml
```

The first four steps are deterministic. `oracle_brief` is the only
stochastic step (sampled). `write_diary` reads artifacts from disk
rather than the memo to avoid wiring drift.

Conventions for this directory:
- recipe-flavor metadata (motif, arc_shape, voice_notes, characters_in_play,
  locations_in_play) lives in `data/jim_story_library.yaml`'s
  `recipe_defaults:` block, NOT a `stories:` map; the obsolete
  `story_id` concept has been removed everywhere
- runtime tuning (model path, max_tokens, temp, top_p, seed) lives in
  `override/jim_story.yaml`
- structural recipe (steps, dependencies, UI directives) lives in
  `config/jim_story.yaml`
