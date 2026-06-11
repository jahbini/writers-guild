Area: `data/jim_story_library.yaml` (the editing surface)

Purpose:
- canonical curatorial source for the corpus
- holds shelves of seeds, named arc shapes, and per-recipe defaults
- shape on disk is human-friendly; load_library flattens to runtime shape

Shape on disk:
```yaml
library:
  scenes:        <location>: [ "<full sentence>"  or  {text: "...", time_affinity: [...]} ]
  characters:    <Name>:     [ "<bare gesture>", ... ]   # name prepended at load
  disturbances:  <theme>:    [ "<full sentence>", ... ]
  reflections:   <family>:   [ "<full sentence>", ... ]
  realizations:  <family>:   [ "<full sentence>", ... ]

arc_shapes:
  <name>:
    desc: "<one-line description>"
    emotions: [ <5 emotions, one per beat in beat order> ]

time_of_day:                  # enum for the UI dropdown
  - dawn
  - morning
  - afternoon
  - evening
  - night

recipe_defaults:
  motif:              <string>          # free-form metadata; one-line oracle cue
  arc_shape:          <name>            # must exist in arc_shapes above
  time_of_day:        <enum value>      # one of the time_of_day entries
  characters_in_play: [ <Name>, ... ]
  locations_in_play:  [ <location>, ... ]
  voice_notes:        <string>
  # Fallback beat picks when UI selections are empty (literal text or flat key):
  scene:        ...
  arrival:      ...
  disturbance:  ...
  reflection:   ...
  realization:  ...
```

Mixed entry shape (within a shelf list):
- bare string `"Fog rolling into the harbor"` — the simplest, most common form
- object `{text: "...", time_affinity: [<time_of_day enum>, ...]}` — when an
  entry has a strong tie to specific times. load_library merges all fields
  from the object onto the flat entry verbatim, so future tags (e.g.,
  `season:`) work the same way without code changes.

The `motif` field is **metadata only**. It does NOT constrain beat selection.
The library has one populated motif (`mind_worm`) in the disturbances shelf
as a thematic bucket key, but motif is otherwise just a one-line cue
threaded through the oracle's meta-prompt. If you want motif-driven beat
selection, that requires (a) tagging entries across all shelves with
`motifs: [...]` and (b) adding a filter step before assemble_ingredients.
Both are out of scope today.

Beat → shelf mapping (load_library, select_story_recipe,
assemble_ingredients all encode this):
- scene       → scenes
- arrival     → characters
- disturbance → disturbances
- reflection  → reflections
- realization → realizations

Invariants:
- every arc_shape lists EXACTLY 5 emotions
- recipe_defaults.arc_shape names a key in arc_shapes
- recipe_defaults beat refs resolve to a library entry (literal text
  preferred; flat keys also accepted by load_library)
- bare-list shape and dict-of-lists shape are both valid per shelf;
  load_library's flatten auto-detects

UI source paths point at this file:
- `UI_grouped_dropdown, data/jim_story_library.yaml/library/scenes`
- `UI_grouped_dropdown, data/jim_story_library.yaml/library/characters`
- ... one per beat

Known pitfalls:
- character entries store BARE gestures ("folds his newspaper carefully");
  load_library reconstructs "<Name> <gesture>" for the model-facing text.
  Other shelves store full sentences as-is.
- adding a 6th emotion to an arc_shape silently breaks assemble_ingredients;
  the runtime requires exactly 5.
- editing a recipe_defaults beat to a string not in the library produces
  a warn on load and a runtime error in resolve_story_parts.
- the previous `stories:` machinery (jim_0001/2/3) is removed; do not
  reintroduce it.
- time_affinity values MUST come from the top-level `time_of_day:` enum.
  Free-form values won't break load_library but won't match the UI
  dropdown's options either, so they'll never round-trip cleanly.
