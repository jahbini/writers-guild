#!/usr/bin/env coffee
###
test/dryrun_write_diary.coffee — invoke the step's action against
the real on-disk artifacts and dump the resulting YAML to stdout.
###

fs   = require 'fs'
path = require 'path'

REPO_ROOT = path.resolve(__dirname, '..')
mod = require path.join(REPO_ROOT, 'scripts/jim/write_diary.coffee')
step = mod.step ? mod['@step'] ? require.cache[require.resolve(path.join(REPO_ROOT, 'scripts/jim/write_diary.coffee'))]?.exports?.step

memo =
  _store: { 'env/CWD': REPO_ROOT }
  saveThis: (k, v) -> @_store[k] = v
  theLowdown: (k) -> { value: @_store[k] }
  getStepParam: -> null

await step.action(memo, 'write_diary')
console.log "diary_file written to:", memo._store['diary_file']
