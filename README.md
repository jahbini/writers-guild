# Writers Guild

A curator's workbench for crafting **story trajectories** and **situations** —
the structured raw material that the downstream
[`writediary`](https://github.com/jahbini/writediary) pipeline turns into
finished diary prose.

This project doesn't generate diaries. It curates the *shapes* of days —
which beat hits when, in what emotional arc, against what motif, in which
parts of the world. A small local LLM step then composes a planning brief
from those ingredients. Writediary consumes that brief.

```
WRITERS GUILD                                  WRITEDIARY
─────────────                                  ──────────
  library of scenes / characters /              (KAG-enabled generator
  disturbances / reflections /          ─▶      turns the brief into
  realizations  +  arc shapes                   first-person diary prose)
        │
        ▼
  curated brief YAML
  (per run, in diary/)
```

## The five beats and the arc

Every day's diary is shaped around five beats in order:

| Beat | What it is |
|---|---|
| **scene** | the atmospheric opening — a sensory place |
| **arrival** | a character appears and does something small |
| **disturbance** | the thing that ruffles the day |
| **reflection** | the interpretive observation |
| **realization** | the punchline insight |

An **arc shape** assigns an emotion to each beat in order, giving the day
its trajectory:

| Shape | Trajectory |
|---|---|
| `settling` | contentment → anxiety → fear → melancholy → resolve |
| `spiral` | calm → suspicion → fear → certainty → defeat |
| `lift` | heaviness → recognition → small_joy → expansion → benediction |
| `st_johns_standard` | Jim's default — contentment → anxiety → fear → contentment → frustration |

Add more in `data/jim_story_library.yaml` under `arc_shapes:`.

## The library

`data/jim_story_library.yaml` is the editing surface for the corpus. Each
shelf is sub-bucketed by its natural axis:

```yaml
library:
  scenes:
    harbor: [ Fog rolling into the harbor, Gulls circling over docks, ... ]
    cafe:   [ Espresso machine hissing, ... ]
    street: [ ... ]
    town:   [ ... ]

  characters:
    Southwick: [ folds his newspaper carefully, raises an eyebrow, ... ]
    Roger:     [ stirs coffee absentmindedly, ... ]
    Tommy:     [ bursts in talking loudly, ... ]

  disturbances:
    mind_worm: [ People repeating slogans without knowing their origin, ... ]
    fear:      [ ... ]
    rumor:     [ ... ]

  reflections:
    water:           [ Ideas move through towns like fog, ... ]
    fire and light:  [ Fear runs through crowds like electricity, ... ]
    ...

  realizations:
    noticing:    [ ... ]
    truth:       [ ... ]
    ...

arc_shapes:
  st_johns_standard: { desc: ..., emotions: [...] }
  ...

recipe_defaults:
  motif: mind_worm
  arc_shape: st_johns_standard
  characters_in_play: [ Southwick ]
  locations_in_play:  [ harbor, cafe, town ]
  voice_notes: St. John's diary, first-person, sensory-dense
  # Fallback beat picks when the UI selections are empty:
  scene:       Fog rolling into the harbor
  arrival:     Southwick folds his newspaper carefully
  disturbance: People repeating slogans without knowing their origin
  reflection:  Ideas move through towns like fog
  realization: The loudest ideas are rarely the wisest
```

Curating *is* the work: add a Tommy gesture, add a harbor scene, add a
mind_worm disturbance, define a new arc_shape, change `recipe_defaults`.

## Running

The UI is the primary mechanism. It shows the 5 beats as accordion
pickers (grouped by sub-bucket), runs the pipeline on Launch, and
surfaces the resulting diary YAML in a panel for inspection.

```bash
pnpm run ui          # http://127.0.0.1:4311  — pick beats, click Launch
pnpm run pipeline    # headless equivalent, uses current UI selections
./test.sh            # smoke test (deterministic chain, no MLX needed)
```

Fresh clone first time:

```bash
./run-first.sh       # installs deps, sets up .venv for MLX, hydrates ui/
```

## Pipeline shape

Six steps. Edits to `config/jim_story.yaml` are structural; runtime
tuning lives in `override/jim_story.yaml` per `GPT/CONVENTIONS.md`.

```
load_library            data/jim_story_library.yaml  →  story_library
select_story_recipe     UI picks + recipe_defaults   →  story_recipe
resolve_story_parts     story_recipe + library       →  story_parts
assemble_ingredients    story_parts + arc_shape      →  ingredient_bundle
oracle_brief            ingredient_bundle + Qwen     →  diary_brief
write_diary             all of the above             →  diary/<recipe>_HH_MM.yaml
```

The diary file is what `writediary` consumes. Its top-level fields:

```yaml
generated_at: ...
recipe: jim_story
motif: mind_worm
arc_shape: st_johns_standard
voice_notes: ...
characters_in_play: [...]
locations_in_play: [...]
beats:
  scene:       { emotion, seed, location }
  arrival:     { emotion, seed, character }
  disturbance: { emotion, seed, theme }
  reflection:  { emotion, seed, family }
  realization: { emotion, seed, family }
brief: |
  <Qwen-composed narrative brief — the prompt writediary expands>
structure_hints:  [ <one line per beat> ]
transitions:      [ <one line per beat-pair> ]
motif_thread:     ...
voice_target:     ...
recipe_overrides: [ <UI-picked beats> ]
```

## Layout

```
config/         pipeline recipes (jim_story.yaml is the live one)
data/           library + arc_shapes + recipe_defaults (tracked .yaml only)
diary/          generated per-run output for writediary (gitignored)
scripts/jim/    the six pipeline steps (load_library through write_diary)
override/       runtime tuning per recipe (jim_story.yaml: model, sampling)
ui/             UI client (index.html — accordion pickers etc.)
ui_server.coffee  pipe-local UI server (renders recipe, launches runs)
GPT/            assistant working memory — conventions and step contracts
test/           smoke test + dry-run harnesses (test.sh is the entry point)
build/          local quantized MLX model (symlink to a sibling project)
node_modules/@jahbini/pipeline/   the upstream pipeline runner
```

Generated at runtime (gitignored): `out/`, `state/`, `params/`,
`experiment.yaml`, `pipeline.json`, `control_override.yaml`,
`runtime.sqlite`, `diary/`, `build/`.

## Further reading

- [`GPT/CONVENTIONS.md`](GPT/CONVENTIONS.md) — what to edit freely, what
  not to touch, how tuning is layered
- [`GPT/pipeline_architecture.md`](GPT/pipeline_architecture.md) — the
  DAG runner, Memo, override hierarchy
- [`GPT/jim_story/`](GPT/jim_story/) — per-step contracts for this
  project's pipeline (read first when working on a specific step)
- [`README_pipeline.md`](README_pipeline.md), [`README_pipeline_step_dev.md`](README_pipeline_step_dev.md)
  — upstream pipeline runner and step-template references
