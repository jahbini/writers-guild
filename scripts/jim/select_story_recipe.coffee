@step =
  desc: "Build story recipe from per-beat UI overrides, falling back to recipe_defaults"

  action: (M, stepName) ->
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

    defaults = bundle?.recipe_defaults ? {}

    recipe = {}
    for k in ['scene','arrival','disturbance','reflection','realization']
      recipe[k] = overrides[k] ? defaults[k]
      unless recipe[k]?
        throw new Error "[#{stepName}] no value for '#{k}' (no UI override, no recipe_defaults entry)"

    out =
      recipe: recipe
      overrides: (k for k, v of overrides when v?)

    M.saveThis "story_recipe", out
    M.saveThis "done:#{stepName}", true
    return
