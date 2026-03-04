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
    await M.need(stepName, 'curl_result')

    cmd  = 'python'
    args = ['-V']
    result = spawnSync(cmd, args, encoding: 'utf8')

    if result.error
      console.error "[#{stepName}] Python failed:", result.error
      M.put stepName, 'python_result', { status: 'failed', error: String(result.error) }
      M.saveThis "done:#{stepName}", true
      return

    output = (result.stdout or result.stderr).trim()
    console.log "[#{stepName}] Python responded:", output

    M.put stepName, 'python_result', { status: 'ok', version: output }
    M.saveThis "done:#{stepName}", true
    return
