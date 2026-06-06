fs   = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

@step =
  desc: "Assemble ingredient bundle from resolved story_parts for the oracle composer"

  action: (M, stepName) ->
    arcShapesFile = M.getStepParam(stepName, 'arc_shapes_file') ? 'data/arc_shapes.yaml'

    library = M.theLowdown('story_library').value
    throw new Error "[#{stepName}] story_library missing from memo" unless library?

    parts = M.theLowdown('story_parts').value
    throw new Error "[#{stepName}] story_parts missing from memo" unless parts?

    storyId = parts.story_id
    # resolve_story_parts writes entries at the top level (parts.scene, etc.).
    # Older expanded outputs wrapped them under .source_parts — accept both.
    source = parts.source_parts ? parts

    # Pull story-level metadata (motif, arc_shape, voice notes, world cast).
    # When per-beat overrides came from the UI, the story_id may still be the
    # named default; we look up its metadata for arc + motif but use the
    # resolved parts as the anchors.
    storyDef = library.stories?[storyId] ? {}
    arcName  = storyDef.arc_shape ? 'st_johns_standard'

    execDir = M.theLowdown('env/EXEC')?.value ? process.cwd()
    cwdDir  = M.theLowdown('env/CWD')?.value  ? process.cwd()
    resolveInputPath = (p) ->
      return p if path.isAbsolute(p)
      candidate = path.resolve(cwdDir, p)
      return candidate if fs.existsSync(candidate)
      path.resolve(execDir, p)

    arcDoc = yaml.load fs.readFileSync(resolveInputPath(arcShapesFile), 'utf8')
    arcShapes = arcDoc.arc_shapes ? {}
    arcShape  = arcShapes[arcName]
    throw new Error "[#{stepName}] Unknown arc_shape #{arcName}" unless arcShape?
    unless Array.isArray(arcShape.emotions) and arcShape.emotions.length is 5
      throw new Error "[#{stepName}] arc_shape #{arcName} must list exactly 5 emotions"

    beats = ['scene','arrival','disturbance','reflection','realization']

    anchor_seeds = for beat, i in beats
      entry = source[beat]
      throw new Error "[#{stepName}] story_parts.source_parts.#{beat} missing" unless entry?
      seed =
        beat: beat
        key: parts.keys?[beat] ? null
        seed: entry.text
        emotion: arcShape.emotions[i]
      seed.location  = entry.location  if entry.location?
      seed.character = entry.character if entry.character?
      seed.theme     = entry.theme     if entry.theme?
      seed.motifs    = entry.motifs    if entry.motifs?
      seed

    bundle =
      story_id: storyId
      motif: storyDef.motif ? null
      arc_shape: arcName
      arc_desc: arcShape.desc ? null
      characters_in_play: storyDef.characters_in_play ? []
      locations_in_play:  storyDef.locations_in_play  ? []
      voice_notes: storyDef.voice_notes ? "St. John's diary, first-person, sensory-dense"
      anchor_seeds: anchor_seeds

    M.saveThis 'ingredient_bundle', bundle
    M.saveThis "done:#{stepName}", true
    return
