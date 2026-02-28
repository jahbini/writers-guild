#!/usr/bin/env coffee
###
direct_merge.coffee — advance raw segments into LoRA train/valid
No oracle, no prompt construction.
###

@step =
  desc: "Advance N unused segments into train; rotate old train into valid"

  action: (M, stepName) ->

    # ------------------------------------------------------------
    # Params
    # ------------------------------------------------------------
    srcKey    = M.getStepParam stepName, 'marshalled_stories'
    trainKey  = M.getStepParam stepName, 'train_file'
    testKey   = M.getStepParam stepName, 'test_file'
    validKey  = M.getStepParam stepName, 'valid_file'
    mergedKey = M.getStepParam stepName, 'merged_segments'
    takeN     = M.getStepParam stepName, 'take_n'

    throw new Error "Missing take_n" unless typeof takeN is 'number'

    # ------------------------------------------------------------
    # Load source + existing datasets
    # ------------------------------------------------------------
    srcRows   = (M.theLowdown(srcKey)?.value ? [])
    oldTrain  = (M.theLowdown(trainKey)?.value ? [])
    oldValid  = (M.theLowdown(validKey)?.value ? [])

    unless Array.isArray(srcRows)
      throw new Error "marshalled_stories must be array"

    oldTrain = [] unless Array.isArray(oldTrain)
    oldValid = [] unless Array.isArray(oldValid)

    # ------------------------------------------------------------
    # Determine unused segments
    #   (by doc_id + paragraph_index)
    # ------------------------------------------------------------
    used = new Set()

    markUsed = (rows) ->
      for r in rows when r?.meta?
        key = "#{r.meta.doc_id}:#{r.meta.paragraph_index}"
        used.add key

    markUsed oldTrain
    markUsed oldValid

    unused = []
    for r in srcRows
      continue unless r?.meta? and r?.text?
      key = "#{r.meta.doc_id}:#{r.meta.paragraph_index}"
      continue if used.has key
      unused.push r

    # ------------------------------------------------------------
    # No work left → SHUTDOWN SIGNAL
    # ------------------------------------------------------------
    if unused.length is 0
      M.saveThis "pipeline:shutdown",
        by: stepName
        reason: "no more untagged segments"
        timestamp: new Date().toISOString()
      return

    # ------------------------------------------------------------
    # Select next batch
    # ------------------------------------------------------------
    newTrain = unused.slice 0, takeN

    # ------------------------------------------------------------
    # Rotate datasets
    # ------------------------------------------------------------
    newValid = oldValid.concat oldTrain
    if newValid.length == 0
      newValid = newTrain

    console.log "[direct_merge]"
    console.log "  total source:", srcRows.length
    console.log "  unused:", unused.length
    console.log "  take_n:", takeN
    console.log "  new train:", newTrain.length
    console.log "  new valid:", newValid.length

    # ------------------------------------------------------------
    # Persist
    # ------------------------------------------------------------
    M.saveThis trainKey, newTrain
    M.saveThis testKey, newTrain
    M.saveThis validKey, newValid
    M.saveThis mergedKey, newTrain

    return
