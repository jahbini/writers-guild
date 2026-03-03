###
Generate a story scene from character profiles and tarot cues
###

CoffeeScript = require 'coffeescript'
CoffeeScript.register()
{ composePrompt } = require './prompts.coffee'

@step =
  desc: "Generate a scene from characters + tarot cues"

  action: (M, stepName) ->
    cfg = M.theLowdown('experiment.yaml')?.value ? {}
    stepCfg = cfg[stepName] ? {}
    onto = await M.need(stepName, 'ontology')
    profiles = await M.need(stepName, 'arcs')

    tarotCue = stepCfg.tarot
    interaction = stepCfg.interaction

    prompt = composePrompt profiles, interaction, tarotCue, onto

    # Placeholder for model generation
    storyText = "TODO: Generated story text via KAG model.\n\nPrompt was:\n#{prompt}"

    M.put stepName, 'scene_text', storyText
    M.saveThis "done:#{stepName}", true
    console.log "Generated scene (#{tarotCue}) and wrote output artifact: scene_text"
    console.log "JIM", storyText,prompt
    return
