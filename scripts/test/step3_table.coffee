#!/usr/bin/env coffee
###
Step 3 — table: generate CSV summary
###
@step =
  name: 'step3_table'
  desc: 'Create tabular summary from transformed data.'

  action: (M, stepName) ->
    summary = M.getStepParam stepName, "summary"
    transformedKey = M.getStepParam stepName, "transformed"
    transformed = M.theLowdown(transformedKey).value
    unless transformed?
      throw new Error "[#{stepName}] Missing memo key transformed"

    row =
      greeting: transformed.greeting
      doubled: transformed.doubled

    M.saveThis summary, row
    console.log "[#{stepName}] wrote", summary
    return
