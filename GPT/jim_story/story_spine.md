Step: `story_spine` (PLANNED — not yet implemented as of 2026-07-30)
Recipe: `jim_story`
Script: `scripts/jim/story_spine.coffee` (to be written)

## Purpose

Sacred structural planner. Converts the resolved atoms + selected lens
into a **deterministic story plan** — a JSON document that later stages
expand into scene plans and finally into prose. Contains no prose. Never
invents or "improves" the author's story; only structures it.

Fills the missing planning layer between `assemble_ingredients` and
prose generation. Currently `oracle_brief` collapses that gap in one
LLM shot; the spine splits it into structural (deterministic contract)
and prose (creative) halves.

## Placement in the recipe

Additive alongside `oracle_brief`:

```
assemble_ingredients → ingredient_bundle
   ├─→ oracle_brief → diary_brief          (existing narrative brief)
   └─→ story_spine  → story_spine.json     (NEW structural plan)
                       ↓
                    write_diary  (both persisted; spine as sidecar for now)
```

Rationale: keeps the diary output working while a future
`scene_planner` + `prose_generator` pair can consume the spine.

## Inputs (from `ingredient_bundle`)

The 4 axis atoms + 3 character slots + lens, from the atoms library:

- `protagonist`, `antagonist`, `witness` — all draw from
  `data/jim_story_library.yaml`'s `story_atoms.characters`. Protagonist
  required; other two optional (nullable).
- `external_problem`, `internal_obstacle`, `missed_opportunity`,
  `primary_consequence` — each from its respective atoms list.
- `lens` (currently the `motif` field, kept as `motif` for coffee
  compatibility) — one of `mind_worm | tarot_major_arcana | four_forces
  | i_ching_hexagram`, backed by `story_atoms.lenses`.

The atoms library at `data/jim_story_library.yaml` currently holds 10
entries in each axis list and 4 lenses. Each atom carries `id`, `label`,
`tags` (or `role_hints`), and a `canonical_phrasing` the spine generator
should incorporate verbatim.

## Output (validated against `schemas/story_spine.schema.json`)

Four top-level sections — no prose anywhere:

- `story` — title, premise, protagonist, dramatic_axis (the four axis
  atoms), starting_state, terminal_state, required_story_events (MUST
  occur), protected_facts (may not be contradicted), generation_freedoms
  (what later stages may invent).
- `questions.central` / `questions.supporting` — what keeps the reader
  reading. IDs like `q_car_broke_down`.
- `causal_spine` — array of `{id: c1|c2|…, event, depends_on, causes,
  opens_questions, closes_questions}`. The logical chain, not a scene
  list.
- `scenes` — the minimum number of dramatic scenes. Each scene has
  `id`, `purpose` (enum: establish_need | introduce_opportunity |
  force_a_decision | raise_stakes | reveal_information |
  lose_an_opportunity | resolve_a_question), `catalyst`,
  `required_events`, `dramatic_pressure`, `required_choice`,
  `required_reveal`, `required_outcomes`, `ending_state`, and
  `carry_forward` (unanswered_questions, unresolved_relationships,
  commitments, risks, obligations, new_knowledge).

Schema is strict: `additionalProperties: false` throughout. Id patterns
enforce `c<n>` for causal steps and `q<snake_case>` for questions.
Failed validation should retry the oracle call (up to a small cap)
before failing the step.

## Determinism contract

The spec is emphatic:

- Never invent a different story.
- Never "improve" the author's story.
- Never solve the story.
- Never write dialogue or narration.
- Preserve immutable facts.

Translated to runtime:
- `mlx.temp: 0` (greedy) for reproducibility until the prompt stabilizes.
- Response constrained to JSON only via the schema in the prompt.
- Schema validation before `S.make`; validation failure → retry.

## Design decisions locked 2026-07-30

- **Library file**: extended existing `data/jim_story_library.yaml` (new
  top-level `story_atoms:` block), not a separate file.
- **Characters**: full cast — protagonist + antagonist + witness slots,
  all draw from one `characters` list. Antagonist / witness are optional.
- **Motif → lens**: `assemble_ingredients.motif` UI field promoted from
  `UI_textarea` to `UI_dropdown` backed by `story_atoms.lenses`. Field
  name kept as `motif` for backwards compatibility with existing coffee
  scripts. Default is `mind_worm`.

## UI dropdown loader (2026-07-30)

`ui_server.coffee`'s `loadDropdownOptions` now recognizes **three** source
shapes:

1. Bare string array — key = label, alphabetized.
2. Object map (`{id: {...}, id: {...}}`) — key = property name, alphabetized.
3. **Array of `{id|key, label, ...}` objects — order preserved.** (new)

Shape (3) is what `story_atoms.lenses` and the 5 axis atom lists use.
Order-preservation matters because the default (`mind_worm`) is
canonically listed first.

## Next steps (for tomorrow)

1. Write `scripts/jim/story_spine.coffee` (sacred style, mirrors
   oracle_brief.coffee's shape but validates output against
   `schemas/story_spine.schema.json`).
2. Add step block to `config/jim_story.yaml` with:
   - `depends_on: [assemble_ingredients]`
   - `needs: [ingredient_bundle]`
   - `makes: [story_spine]`
   - 3 character dropdowns + 4 axis dropdowns backed by `story_atoms.*`
3. Add `oracle_brief.mlx`-style block for `story_spine` in
   `override/jim_story.yaml`, with `temp: 0`.
4. Extend `write_diary` to persist the spine JSON alongside the brief.
5. Author the spine generator system prompt (the spec at the top of
   this doc — the "Story Spine Generator" contract).
