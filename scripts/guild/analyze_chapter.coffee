###
Analyze a story chapter for character energies (Four Forces)
Outputs JSON arc data into memo (out/arcs.json)
###

{ scoreSegment, computeMetrics } = require './scoring.coffee'
CoffeeScript = require 'coffeescript'
CoffeeScript.register()

@step =
  desc: "Analyze a chapter text and compute character energy arcs"

  action: (M, stepName) ->
    text = await M.need(stepName, 'chapter_text')
    onto = await M.need(stepName, 'ontology')
    charList = await M.need(stepName, 'characters')
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
      segScore = scoreSegment para, onto
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

    M.put stepName, 'arcs', arcs
    M.saveThis "done:#{stepName}", true
    console.log "Analyzed chapter and wrote output artifact: arcs"
    return
