Step: `write_diary`
Recipe: `jim_story`
Script: `scripts/jim/write_diary.coffee`

Purpose:
- consolidate the run's artifacts into one self-contained diary YAML
- write to `diary/<recipe>_HH_MM.yaml` so the UI's Diary Files panel
  surfaces it as a new item per run

Inputs (read from disk, NOT the memo — see "Why disk" below):
- `out/ingredient_bundle.json`
- `out/diary_brief.json`
- `out/story_recipe.json`

Outputs:
- file: `diary/<recipe>_HH_MM.yaml`
- artifact `diary_file`: the absolute path of the file written

Diary YAML shape (top-level fields, in this order):
```yaml
generated_at: <ISO timestamp>
recipe: jim_story
motif:
arc_shape:
arc_desc:
voice_notes:
characters_in_play:
locations_in_play:
beats:
  scene:       { emotion, seed, location?  }
  arrival:     { emotion, seed, character? }
  disturbance: { emotion, seed, theme?     }
  reflection:  { emotion, seed, family?    }
  realization: { emotion, seed, family?    }
brief:           # from oracle_brief
structure_hints: # from oracle_brief
transitions:     # from oracle_brief
motif_thread:    # from oracle_brief
voice_target:    # from oracle_brief
oracle_brief_raw: # ONLY when extractor failed (brief.brief absent)
recipe_overrides: # ONLY when story_recipe.overrides non-empty
```

Filename:
- `<recipe>_<HH>_<MM>.yaml` — local time, two runs in same minute overwrite
- the recipe_name is a step param; defaults to `jim_story`

Why disk (not memo):
- under specific upstream-runner wiring/resume paths the memo's
  `diary_brief` key could resolve to the wrong artifact (we observed
  it returning the ingredient_bundle). Couldn't pin the exact cause,
  so we read from disk, which is authoritative. The memo lookup remains
  as a fallback when the file is absent.

Invariants:
- writes exactly one file per invocation
- does NOT emit `story_id` (obsolete)
- the `brief:` field is bubbled up from `diary_brief.brief` only when
  extraction succeeded; if missing, the full payload lands as
  `oracle_brief_raw:` for inspection

Downstream consumer:
- `writediary`'s diary_ite recipe consumes `story_parts` (NOT this YAML).
  The diary YAML is curator-facing: it's the artifact you read after a
  run to see what got made.

Known pitfalls:
- if `out/*.json` is stale from a previous run, the diary YAML is stale
  too. `assemble_ingredients` / `oracle_brief` re-running fixes this.
- the test harness `test/dryrun_write_diary.coffee` invokes the action
  against the on-disk artifacts without the pipeline — ~50ms verification
  cycle when iterating on the YAML shape.
