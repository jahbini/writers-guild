#!/usr/bin/env coffee
###
Step 6 — curl: external network test
###
{ spawnSync } = require 'child_process'

@step =
  name: 'step6_curl'
  desc: 'Spawn a curl request and memoize its result.'

  action: (M, stepName) ->
    console.log "[#{stepName}] running curl..."
    resultKey = M.getStepParam(stepName, 'curl_result') ? "data/curl_result.json"

    cmd  = 'curl'
    args = ['-sI', 'https://example.com']
    result = spawnSync(cmd, args, encoding: 'utf8')

    if result.error
      console.error "[#{stepName}] curl failed:", result.error
      M.saveThis resultKey, { status: 'failed', error: String(result.error) }
      return

    output = result.stdout.trim()
    console.log "[#{stepName}] curl completed; length:", output.length

    M.saveThis resultKey, { status: 'ok', output }
    return
