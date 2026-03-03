###
Analyze a story chapter for character energies (Four Forces)
Outputs JSON arc data into memo (out/arcs.json)
###

fs   = require 'fs'
path = require 'path'
{ scoreSegment, aggregateScores, computeMetrics } = require './scoring.coffee'
CoffeeScript = require 'coffeescript'
CoffeeScript.register()
{ composePrompt } = require './prompts.coffee'

@step =
  desc: "Analyze a chapter text and compute character energy arcs"

  action: (M, stepName) ->
    throw new Error "Missing stepName" unless stepName?
    cfg = M.theLowdown('experiment.yaml')?.value
    throw new Error "Missing experiment.yaml in memo" unless cfg?
    stepCfg = cfg[stepName]
    throw new Error "Missing step config for '#{stepName}'" unless stepCfg?

    chapterFile = stepCfg.chapter
    textEntry = M.theLowdown(chapterFile)
    text = textEntry.value
    text = await textEntry.notifier unless text?
    throw new Error "No chapter text available" unless text?

    ontoPath = stepCfg.ontology
    onto = JSON.parse fs.readFileSync(ontoPath, 'utf8')

    charList = stepCfg.characters
    arcs = {}
    for name in charList
      arcs[name] =
        summary: ""
        timeline: []

    # --- extremely simplified segmentation for now ---
    paragraphs = text.split(/\n\s*\n+/)
    sceneIndex = 0
    for para in paragraphs
      sceneIndex += 1
      segScore = scoreSegment para, onto, stepCfg
      for ch of arcs
        arcs[ch].timeline.push
          scene: sceneIndex
          title: "Scene #{sceneIndex}"
          Logos: segScore.Logos
          Ethos: segScore.Ethos
          Pathos: segScore.Pathos
          Anima: segScore.Anima
          tarot: segScore.tarot ? []

    for ch, data of arcs
      data.metrics = computeMetrics data.timeline

    M.saveThis "out/arcs.json", arcs
    M.saveThis "done:#{stepName}", true
    console.log "Analyzed chapter: #{chapterFile}, wrote arcs.json"
    return
