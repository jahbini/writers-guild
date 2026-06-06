@step =
  desc: "Select story recipe by per-beat UI overrides or fall back to story_id"

  action: (M, stepName) ->
    # Per-beat overrides come from UI_dropdown fields in config/jim_story.yaml.
    # An empty string from the UI means "no override" — fall through to the
    # named story.
    pick = (k) ->
      v = M.getStepParam(stepName, k)
      if typeof v is 'string' and v.length > 0 then v else null

    overrides =
      scene:       pick 'scene'
      arrival:     pick 'arrival'
      disturbance: pick 'disturbance'
      reflection:  pick 'reflection'
      realization: pick 'realization'

    libraryEntry = M.theLowdown 'story_library'
    bundle = libraryEntry?.value
    if bundle is undefined
      if typeof libraryEntry?.waitFor is 'function'
        bundle = await libraryEntry.waitFor()
      else if libraryEntry?.notifier?
        bundle = await libraryEntry.notifier
    throw new Error "[#{stepName}] Missing input key 'story_library'" if bundle is undefined

    storyId = M.getStepParam(stepName, 'story_id') ? 'jim_0001'
    stories = bundle?.stories ? {}
    base = stories[storyId] ? {}

    # If the named story is missing AND no per-beat overrides were provided,
    # that's an error. If overrides cover the missing slots, we're fine.
    recipe = {}
    for k in ['scene','arrival','disturbance','reflection','realization']
      recipe[k] = overrides[k] ? base[k]
      unless recipe[k]?
        known = Object.keys(stories)
        throw new Error "[#{stepName}] no value for '#{k}' (story_id=#{storyId}, known: #{known.join(', ')})"

    out =
      story_id: storyId
      recipe: recipe
      overrides: (k for k, v of overrides when v?)

    M.saveThis "story_recipe", out
    M.saveThis "done:#{stepName}", true
    return
