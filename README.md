# Writers Guild

A reactive CoffeeScript pipeline for assembling, expanding, and polishing
long-form written work — plus the content corpus it operates on.

The runner started life as an MLX fine-tuning harness and has been
re-purposed as a general-purpose, memo-driven pipeline for text generation
and curation tasks.

## Layout

```
config/         pipeline recipes (jim_story.yaml, defaults, etc.)
content/        the corpus — essays, provenance notes, mind-worm pieces
scripts/        pipeline step implementations
  jim/          story assembly / expansion / polishing steps
library/        reference material consumed by the steps
meta/           metadata describing content
ontologies/     taxonomy / schema definitions
schemas/        JSON schemas
notebooks/      exploratory / archived Jupyter notebooks
tests/          test suite
examples/       example inputs / outputs
override.yaml   selects which pipeline to run
pipeline_runner.coffee     reactive pipeline runner
pipeline_evaluator.coffee  companion evaluator
```

Generated at runtime (gitignored): `data/`, `out/`, `state/`, `params/`,
`pipeline.json`, `eval_out/`, `runs/`, `dist/`.

## Running a pipeline

Pick a pipeline in `override.yaml`:

```yaml
pipeline: jim_story
```

Then:

```bash
make all
```

## Further reading

- [`README_pipeline.md`](README_pipeline.md) — pipeline runtime, memo
  semantics, directory conventions
- [`README_pipeline_step_dev.md`](README_pipeline_step_dev.md) — how to
  write new pipeline steps
