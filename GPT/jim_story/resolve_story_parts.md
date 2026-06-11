Step: `resolve_story_parts`
Recipe: `jim_story`
Script: `scripts/jim/resolve_story_parts.coffee`

Purpose:
- look up each beat's flat key in the library shelf and produce the
  resolved entry payload at the top level of the artifact
- this is the artifact downstream `writediary` consumes (per
  `GPT/diary_ite/build_diary_prompt_ite.md`)

Inputs:
- artifact `story_library`
- artifact `story_recipe`

Outputs:
- artifact `story_parts`:
  ```
  {
    keys: { scene, arrival, disturbance, reflection, realization },
    scene:       { text, location? },
    arrival:     { text, character },
    disturbance: { text, theme? },
    reflection:  { text, family? },
    realization: { text, family? }
  }
  ```

`keys` echoes the recipe's flat keys for round-trip traceability.
The per-beat objects are the same entries `load_library` flattened
out of the editing-surface YAML.

Invariants:
- if any beat's key is missing from its shelf, throw — do NOT silently
  drop or produce an empty entry. Catching this here protects writediary.
- the top-level keys are exactly: `keys`, `scene`, `arrival`,
  `disturbance`, `reflection`, `realization`. Nothing else. The
  obsolete `story_id` field is GONE.

Known pitfalls:
- The downstream writediary code in `GPT/diary_ite/build_diary_prompt_ite.md`
  treats `story_parts` as its canonical event scaffold. Adding new
  top-level fields here is a contract change that affects writediary.
- The old `expand_story_parts` step is gone; nothing wraps these
  entries under a `source_parts:` key anymore. `assemble_ingredients`
  still accepts both shapes for forward compatibility, but no current
  step produces the wrapped shape.
