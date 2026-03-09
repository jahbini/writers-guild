@step =
  desc: "Resolve story recipe keys into expanded story parts"

  action: (M, stepName) ->
    bundle = await M.need(stepName, 'story_library')
    selected = await M.need(stepName, 'story_recipe')

    lib = bundle?.library ? {}
    recipe = selected?.recipe ? {}

    needKey = (shelfName, keyName) ->
      shelf = lib?[shelfName] ? {}
      value = shelf?[keyName]
      unless value?
        throw new Error "[#{stepName}] Missing #{shelfName}.#{keyName}"
      value

    sceneKey = recipe?.scene
    arrivalKey = recipe?.arrival
    disturbanceKey = recipe?.disturbance
    reflectionKey = recipe?.reflection
    realizationKey = recipe?.realization

    out =
      story_id: selected?.story_id
      keys:
        scene: sceneKey
        arrival: arrivalKey
        disturbance: disturbanceKey
        reflection: reflectionKey
        realization: realizationKey
      scene: needKey 'scenes', sceneKey
      arrival: needKey 'characters', arrivalKey
      disturbance: needKey 'disturbances', disturbanceKey
      reflection: needKey 'reflections', reflectionKey
      realization: needKey 'realizations', realizationKey

    M.put stepName, 'story_parts', out
    M.saveThis "done:#{stepName}", true
    return
