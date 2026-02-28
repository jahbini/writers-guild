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

    ontoPath = stepCfg.ontology or "ontologies/four_forces_tarot_master.json"
    onto = JSON.parse fs.readFileSync(ontoPath, 'utf8')

    profilesFile = stepCfg.profiles or "examples/sample_profiles.json"
    profiles = M.theLowdown(profilesFile)?.value ? JSON.parse fs.readFileSync(profilesFile, 'utf8')

    tarotCue = stepCfg.tarot or "Temperance XIV"
    interaction = stepCfg.interaction or "Two characters meet and change each other."

    prompt = composePrompt profiles, interaction, tarotCue, onto
    M.saveThis "prompt:#{stepName}", prompt

    # Placeholder for model generation
    storyText = "TODO: Generated story text via KAG model.\n\nPrompt was:\n#{prompt}"

    M.saveThis "out/scene.txt", storyText
    M.saveThis "done:#{stepName}", true
    console.log "Generated scene (#{tarotCue}) and saved to out/scene.txt"
    console.log "JIM", storyText,prompt
    return
