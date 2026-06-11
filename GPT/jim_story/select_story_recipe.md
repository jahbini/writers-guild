Step: `select_story_recipe`
Recipe: `jim_story`
Script: `scripts/jim/select_story_recipe.coffee`

Purpose:
- build the per-beat recipe from UI selections, falling back to
  `recipe_defaults` when a beat's UI selection is empty
- this is the UI's authoritative point of contact with the pipeline

Inputs:
- artifact `story_library`
- step params (each a `UI_grouped_dropdown` directive in config):
  - `scene`
  - `arrival`
  - `disturbance`
  - `reflection`
  - `realization`

Each param is either an empty string (use default) or a flat key (the
canonical slug from load_library).

Outputs:
- artifact `story_recipe`:
  ```
  {
    recipe: {
      scene:       <flat_key>,
      arrival:     <flat_key>,
      disturbance: <flat_key>,
      reflection:  <flat_key>,
      realization: <flat_key>
    },
    overrides: [ <beat names whose UI param was non-empty> ]
  }
  ```

Resolution per beat:
1. UI param non-empty → use it
2. else → `story_library.recipe_defaults[beat]` (already resolved to
   a flat key by load_library)
3. else → throw — there is no third fallback. Every beat must end up
   with a key.

`overrides` is a small list for traceability — written to the diary
file as `recipe_overrides:` so a curator can tell at a glance which
beats were UI-picked vs. defaulted.

Invariants:
- `story_recipe.recipe` has exactly the 5 beat keys, all set
- the obsolete `story_id` concept is GONE; do not add it back

Known pitfalls:
- UI sends the empty string `""` for "no selection." Not `null` /
  `undefined`. Check explicitly: `typeof v is 'string' and v.length > 0`.
- If you bypass the UI and write `state/ui-control.json` by hand,
  remember the values are flat keys (snake_case slugs), not literal
  texts. Run load_library to see the canonical mapping.
