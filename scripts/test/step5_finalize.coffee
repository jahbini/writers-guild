#!/usr/bin/env coffee
###
Step 5 — finalize: aggregate results
###
@step =
  name: 'step5_finalize'
  desc: 'Aggregate upstream results into final summary.'

  action: (M, stepName) ->
    inputVal = await M.need(stepName, 'input_data')
    transformedVal = await M.need(stepName, 'transformed_data')
    waited = await M.need(stepName, 'wait_data')

    summary =
      original:  inputVal
      doubled:   transformedVal?.doubled
      transformed: transformedVal
      waited:    waited
      timestamp: new Date().toISOString()

    M.put stepName, 'final_summary_json', summary
    M.put stepName, 'final_summary_yaml', summary
    M.put stepName, 'final_summary_csv', summary
    M.saveThis "done:#{stepName}", true
    console.log "[#{stepName}] wrote output artifacts final_summary_*"
    return
