#!/usr/bin/env coffee
###
Step 3 — table: generate CSV summary
###
@step =
  name: 'step3_table'
  desc: 'Create tabular summary from transformed data.'

  action: (M, stepName) ->
    transformed = await M.need(stepName, 'transformed_data')
    unless transformed?
      throw new Error "[#{stepName}] Missing memo key transformed"

    row =
      greeting: transformed.greeting
      doubled: transformed.doubled

    M.put stepName, 'summary_row', row
    M.saveThis "done:#{stepName}", true
    console.log "[#{stepName}] wrote output artifact summary_row"
    return
