#!/usr/bin/env coffee
###
Step 2 — transform: read input.json and write derived output
###
@step =
  name: 'step2_transform'
  desc: 'Transform input.json into doubled numeric output.'

  action: (M, stepName) ->
    input = await M.need(stepName, 'input_data')
    unless input?
      throw new Error "[#{stepName}] Missing memo key input"

    transformed =
      greeting: "#{input.greeting}, world!"
      doubled: input.value * 2

    M.put stepName, 'transformed_data', transformed
    M.saveThis "done:#{stepName}", true
    console.log "[#{stepName}] wrote output artifact transformed_data"
    return
