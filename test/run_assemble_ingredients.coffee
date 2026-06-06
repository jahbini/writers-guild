#!/usr/bin/env coffee
###
test/run_assemble_ingredients.coffee

Standalone harness for scripts/jim/assemble_ingredients.coffee.
Mocks the Memo so the step can run without the full pipeline runner
(and without MLX). Loads the real library YAML, drives the step,
writes the resulting bundle to test/ingredient_bundle.json, and
asserts on its shape.

Usage:
  coffee test/run_assemble_ingredients.coffee [story_id]
###

fs   = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

REPO_ROOT = path.resolve(__dirname, '..')
STORY_ID  = process.argv[2] ? 'jim_0001'

# ------------------------------------------------------------
# Build a minimal Memo stub matching the surface the step uses.
# ------------------------------------------------------------
makeMemo = ->
  store = {}
  params =
    select_story_recipe:
      story_id: STORY_ID
    resolve_story_parts: {}
    assemble_ingredients:
      arc_shapes_file: 'data/arc_shapes.yaml'

  memo =
    saveThis: (k, v) -> store[k] = v
    theLowdown: (k) -> { value: store[k] }
    getStepParam: (stepName, key) -> params[stepName]?[key]
    _store: store

  # Seed env/EXEC and env/CWD so the step can resolve paths
  memo.saveThis 'env/EXEC', REPO_ROOT
  memo.saveThis 'env/CWD',  REPO_ROOT

  memo

# ------------------------------------------------------------
# Load the real library YAML into the memo, then drive the step.
# ------------------------------------------------------------
main = ->
  libraryPath = path.join(REPO_ROOT, 'data/jim_story_library.yaml')
  unless fs.existsSync(libraryPath)
    die "Missing #{libraryPath}"

  doc = yaml.load fs.readFileSync(libraryPath, 'utf8')
  storyLibrary =
    source_file: libraryPath
    library: doc.library
    stories: doc.stories

  M = makeMemo()
  M.saveThis 'story_library', storyLibrary

  # Drive select_story_recipe + resolve_story_parts through the same Memo,
  # so assemble_ingredients reads a real story_parts shape — the same chain
  # the live pipeline runs.
  for stepName in ['select_story_recipe', 'resolve_story_parts']
    mod = require path.join(REPO_ROOT, "scripts/jim/#{stepName}.coffee")
    s = mod.step ? mod['@step'] ? require.cache[require.resolve(path.join(REPO_ROOT, "scripts/jim/#{stepName}.coffee"))]?.exports?.step
    die "Could not load @step from #{stepName}" unless s?.action?
    # select_story_recipe takes story_id; both steps consult getStepParam
    await s.action(M, stepName)

  stepModule = require path.join(REPO_ROOT, 'scripts/jim/assemble_ingredients.coffee')
  step = stepModule.step ? stepModule['@step']

  # CoffeeScript `@step =` exports onto exports.step in the runner; under
  # plain require() we use the module's `@`-bound export
  step ?= require.cache[require.resolve(path.join(REPO_ROOT, 'scripts/jim/assemble_ingredients.coffee'))]?.exports?.step

  unless step?.action?
    die "Could not locate @step on assemble_ingredients module"

  await step.action(M, 'assemble_ingredients')

  bundle = M._store['ingredient_bundle']
  unless bundle?
    die "Step ran but no ingredient_bundle was saved"

  outDir  = path.join(REPO_ROOT, 'test')
  outPath = path.join(outDir, 'ingredient_bundle.json')
  fs.mkdirSync(outDir, recursive: true)
  fs.writeFileSync outPath, JSON.stringify(bundle, null, 2)

  assertions = runAssertions(bundle)
  reportPath = path.join(outDir, 'assertions.json')
  fs.writeFileSync reportPath, JSON.stringify(assertions, null, 2)

  failed = (a for a in assertions when not a.pass)
  for a in assertions
    flag = if a.pass then 'OK  ' else 'FAIL'
    console.log "[#{flag}] #{a.name}#{ if a.detail then ' — ' + a.detail else '' }"

  console.log "\nBundle written to #{outPath}"
  console.log "Report written to #{reportPath}"

  if failed.length > 0
    console.error "\n#{failed.length} assertion(s) failed"
    process.exit 1
  else
    console.log "\nAll #{assertions.length} assertions passed"
    process.exit 0

# ------------------------------------------------------------
# Assertions on the bundle shape
# ------------------------------------------------------------
runAssertions = (b) ->
  beats = ['scene','arrival','disturbance','reflection','realization']
  results = []
  push = (name, pass, detail) -> results.push { name, pass, detail }

  push 'bundle has story_id',     b.story_id is STORY_ID,
    "got #{b.story_id}"
  push 'bundle has arc_shape',    typeof b.arc_shape is 'string'
  push 'bundle has voice_notes',  typeof b.voice_notes is 'string'

  push 'characters_in_play is array', Array.isArray(b.characters_in_play)
  push 'locations_in_play is array',  Array.isArray(b.locations_in_play)

  seeds = b.anchor_seeds
  push 'anchor_seeds is array of 5',
    Array.isArray(seeds) and seeds.length is 5,
    "len=#{seeds?.length}"

  if Array.isArray(seeds) and seeds.length is 5
    for beat, i in beats
      s = seeds[i]
      push "beat[#{i}] is #{beat}", s?.beat is beat, "got #{s?.beat}"
      push "beat[#{i}].key set",       typeof s?.key is 'string'
      push "beat[#{i}].seed set",      typeof s?.seed is 'string' and s.seed.length > 0
      push "beat[#{i}].emotion set",   typeof s?.emotion is 'string'

  # Determinism: run twice, ensure identical
  results

# ------------------------------------------------------------
die = (msg) ->
  console.error msg
  process.exit 2

main().catch (err) ->
  console.error err.stack ? err
  process.exit 3
