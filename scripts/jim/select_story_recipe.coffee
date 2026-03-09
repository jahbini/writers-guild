@step =
  desc: "Select deterministic story recipe by story_id"

  action: (M, stepName) ->
    storyId = M.getStepParam(stepName, 'story_id') ? 'jim_0001'
    bundle = await M.need(stepName, 'story_library')

    stories = bundle?.stories ? {}
    selected = stories?[storyId]

    unless selected?
      known = Object.keys(stories)
      throw new Error "[#{stepName}] story_id '#{storyId}' not found. Known: #{known.join(', ')}"

    out =
      story_id: storyId
      recipe: selected

    M.put stepName, 'story_recipe', out
    M.saveThis "done:#{stepName}", true
    return
