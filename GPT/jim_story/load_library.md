Step: `load_library`
Recipe: `jim_story`
Script: `scripts/jim/load_library.coffee`

Purpose:
- read the clean editing-surface schema from `data/jim_story_library.yaml`
- flatten library shelves into the keyed-dict shape downstream expects
- carry arc_shapes through unchanged
- resolve recipe_defaults beat refs (literal text → flat key)

Inputs:
- file: `data/jim_story_library.yaml` (via step param `library_file`)

Outputs:
- artifact `story_library`:
  ```
  {
    source_file: <path>,
    library: {
      scenes:        { <flat_key>: { text, location } },
      characters:    { <flat_key>: { text, character } },
      disturbances:  { <flat_key>: { text, theme } },
      reflections:   { <flat_key>: { text, family } },
      realizations:  { <flat_key>: { text, family } }
    },
    arc_shapes: { <name>: { desc, emotions } },
    recipe_defaults: { motif, arc_shape, ..., scene, arrival, ... }
      # beat refs in recipe_defaults are resolved to flat keys here
  }
  ```

Flat key algorithm (must stay in sync with `ui_server.coffee`'s `slug`):
- lowercase
- strip non-ASCII (no transliteration: `café` → `caf`)
- non-alphanum → `_`
- collapse repeated `_`, trim leading/trailing `_`
- truncate to 48 chars
- on collision, append `_2`, `_3`, ...

Shape detection in `flatten()` per shelf:
1. Array → bare list (no sub-bucket)
2. Object whose values are arrays → dict-of-lists (sub-buckets)
3. Object whose values look like `{text, ...}` → legacy dict-of-leaves
   (backward compat with old library shape)

For characters, the bucket key is the character name; entries store BARE
gestures and load_library reconstructs `<Name> <gesture>` as the entry's
`text:` field. The `character:` field carries the name through to
write_diary for traceability.

Invariants:
- `story_library.library` has exactly the 5 named shelves
- every flat key in the output corresponds to one entry; collisions get
  suffixed; nothing is silently dropped
- `story_library.arc_shapes` may be empty if absent in the source

Known pitfalls:
- The slug function MUST match `ui_server.coffee`'s. Drift here breaks
  the UI dropdown round-trip (selection saved by UI won't match the
  flat key produced by load_library).
- If a `recipe_defaults.<beat>` literal text doesn't appear in the
  corresponding shelf, load_library only warns (not errors). The error
  surfaces downstream in `resolve_story_parts`. Treat the warn as a
  curatorial todo.
