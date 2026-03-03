###
Generate a story scene from character profiles and tarot cues
###

fs   = require 'fs'
path = require 'path'
CoffeeScript = require 'coffeescript'
CoffeeScript.register()
{ composePrompt } = require './prompts.coffee'

@step =
  desc: "Generate a scene from characters + tarot cues"

  action: (M, stepName) ->
    throw new Error "Missing stepName" unless stepName?
    cfg = M.theLowdown('experiment.yaml')?.value
    throw new Error "Missing experiment.yaml in memo" unless cfg?
    stepCfg = cfg[stepName]
    throw new Error "Missing step config for '#{stepName}'" unless stepCfg?

    ontoPath = stepCfg.ontology
    onto = JSON.parse fs.readFileSync(ontoPath, 'utf8')

    profilesFile = stepCfg.profiles
    profilesEntry = M.theLowdown(profilesFile)
    profiles = profilesEntry.value
    profiles = await profilesEntry.notifier unless profiles?

    tarotCue = stepCfg.tarot
    interaction = stepCfg.interaction

    prompt = composePrompt profiles, interaction, tarotCue, onto
    M.saveThis "prompt:#{stepName}", prompt

    # Placeholder for model generation
    storyText = "TODO: Generated story text via KAG model.\n\nPrompt was:\n#{prompt}"

    M.saveThis stepCfg.output, storyText
    M.saveThis "done:#{stepName}", true
    console.log "Generated scene (#{tarotCue}) and saved to #{stepCfg.output}"
    console.log "JIM", storyText,prompt
    return
