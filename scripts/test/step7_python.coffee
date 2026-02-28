#!/usr/bin/env coffee
###
Step 7 — python: external interpreter test
###
{ spawnSync } = require 'child_process'

@step =
  name: 'step7_python'
  desc: 'Run Python interpreter and capture version.'

  action: (M, stepName) ->
    console.log "[#{stepName}] querying Python version..."
    resultKey = M.getStepParam(stepName, 'python_result') ? "data/python_result.json"

    cmd  = 'python'
    args = ['-V']
    result = spawnSync(cmd, args, encoding: 'utf8')

    if result.error
      console.error "[#{stepName}] Python failed:", result.error
      M.saveThis resultKey, { status: 'failed', error: String(result.error) }
      return

    output = (result.stdout or result.stderr).trim()
    console.log "[#{stepName}] Python responded:", output

    M.saveThis resultKey, { status: 'ok', version: output }
    return
