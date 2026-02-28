#!/usr/bin/env coffee
###
Step 5 — finalize: aggregate results
###
@step =
  name: 'step5_finalize'
  desc: 'Aggregate upstream results into final summary.'

  action: (M, stepName) ->
    inputKey = M.getStepParam stepName, "input"
    transformedKey = M.getStepParam stepName, "transformed"
    waitKey = M.getStepParam stepName, "wait"
    input = M.theLowdown(inputKey)
    transformed = M.theLowdown(transformedKey)
    waitedEntry = M.theLowdown(waitKey)
    # if no value wait for that memo entry to be filled
    waited = waitedEntry.value
    waited = await waitedEntry.notifier unless waited?
    inputVal = input.value
    transformedVal = transformed.value

    summary =
      original:  inputVal
      doubled:   transformedVal?.doubled
      transformed: transformedVal
      waited:    waited
      timestamp: new Date().toISOString()

    M.saveThis "data/final_summary.json", summary
    M.saveThis "data/final_summary.yaml", summary
    M.saveThis "data/final_summary.csv", summary
    console.log "[#{stepName}] wrote data/final_summary.json"
    return
