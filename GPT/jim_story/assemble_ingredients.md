Step: `assemble_ingredients`
Recipe: `jim_story`
Script: `scripts/jim/assemble_ingredients.coffee`

Purpose:
- package story_parts + arc_shape + recipe_defaults into one
  ingredient bundle for the oracle composer
- assign one emotion per beat from the arc_shape's emotion sequence

Inputs:
- artifact `story_library` (for `arc_shapes` and `recipe_defaults`)
- artifact `story_parts`
- step params (any override recipe_defaults if set, empty UI string = no override):
  - `motif`         — free-form metadata; just an oracle prompt cue
  - `arc_shape`     — `UI_dropdown` on `arc_shapes`
  - `time_of_day`   — `UI_dropdown` on `time_of_day` enum
  - `characters_in_play`
  - `locations_in_play`
  - `voice_notes`

Outputs:
- artifact `ingredient_bundle`:
  ```
  {
    motif:              <string|null>,        # metadata; oracle prompt cue
    arc_shape:          <name>,
    arc_desc:           <desc from arc_shapes[arc_shape]>,
    time_of_day:        <enum value|null>,
    characters_in_play: [ <Name>, ... ],
    locations_in_play:  [ <location>, ... ],
    voice_notes:        <string>,
    anchor_seeds: [
      { beat, key, seed, emotion,
        location?|character?|theme?|family?|motifs?,
        time_affinity?   # only on the scene seed, if tagged in the library
      }
    ]   # exactly 5 entries, in beat order
  }
  ```

Emotion assignment:
- `arc_shape` looked up in `library.arc_shapes`
- `arcShape.emotions[i]` assigned to `anchor_seeds[i].emotion` in beat
  order: scene, arrival, disturbance, reflection, realization

Source field flow:
- `parts.<beat>.text` → `anchor_seeds[i].seed`
- `parts.keys[<beat>]` → `anchor_seeds[i].key`
- optional metadata from the resolved entry carried through:
  location, character, theme, family

Invariants:
- exactly 5 anchor_seeds, in canonical beat order
- arc_shape must exist in story_library.arc_shapes; its emotions
  array must have length 5; otherwise throw
- the obsolete `story_id` field is NOT emitted on the bundle

Param resolution helper (`pickParam`):
- step param value if set, else recipe_defaults value, else hardcoded
  default (voice_notes only)

Known pitfalls:
- `parts.source_parts` is accepted as a fallback location for the
  resolved entries (legacy wrapper from the deleted expand_story_parts
  step). No current upstream produces it, but the read path tolerates it.
- changing the arc_shape mid-curation is the highest-leverage knob —
  same beat keys, totally different emotional trajectory.
- `pickParam` now treats empty UI strings as "no override" (the UI sends
  `""` for an unselected `UI_dropdown`). Don't break that — `null`-only
  fallthrough would force the curator to pick on every run.
- motif is **metadata-only**: it labels the day's preoccupation for the
  oracle but does NOT filter beat picks. If the library doesn't carry
  motif-tagged entries on a shelf, the motif label is pure prompt cue.
