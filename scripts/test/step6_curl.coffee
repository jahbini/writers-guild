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
    await M.need(stepName, 'final_summary_json')

    cmd  = 'curl'
    args = ['-sI', 'https://example.com']
    result = spawnSync(cmd, args, encoding: 'utf8')

    if result.error
      console.error "[#{stepName}] curl failed:", result.error
      M.put stepName, 'curl_result', { status: 'failed', error: String(result.error) }
      M.saveThis "done:#{stepName}", true
      return

    output = result.stdout.trim()
    console.log "[#{stepName}] curl completed; length:", output.length

    M.put stepName, 'curl_result', { status: 'ok', output }
    M.saveThis "done:#{stepName}", true
    return
