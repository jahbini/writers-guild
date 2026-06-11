@step =
  desc: "Assemble ingredient bundle from resolved story_parts for the oracle composer"

  action: (M, stepName) ->
    library = M.theLowdown('story_library').value
    throw new Error "[#{stepName}] story_library missing from memo" unless library?

    parts = M.theLowdown('story_parts').value
    throw new Error "[#{stepName}] story_parts missing from memo" unless parts?

    # resolve_story_parts writes entries at the top level (parts.scene, etc.).
    # Older expanded outputs wrapped them under .source_parts — accept both.
    source = parts.source_parts ? parts

    # Per-recipe metadata (motif, arc_shape, voice notes, world cast,
    # time_of_day) comes from the library's top-level recipe_defaults block.
    # Step params on this step can override individual fields. Empty UI
    # strings count as "no override" and fall through to defaults.
    defaults = library.recipe_defaults ? {}
    pickParam = (k) ->
      v = M.getStepParam(stepName, k)
      v = null if typeof v is 'string' and v.length is 0
      v ? defaults[k]
    arcName = pickParam('arc_shape') ? 'st_johns_standard'

    # arc_shapes come from the same library artifact now (merged in load_library).
    arcShapes = library.arc_shapes ? {}
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
      motif: pickParam('motif') ? null
      arc_shape: arcName
      arc_desc: arcShape.desc ? null
      time_of_day: pickParam('time_of_day') ? null
      characters_in_play: pickParam('characters_in_play') ? []
      locations_in_play:  pickParam('locations_in_play')  ? []
      voice_notes: pickParam('voice_notes') ? "St. John's diary, first-person, sensory-dense"
      anchor_seeds: anchor_seeds

    # Surface the scene's time_affinity in the anchor seed when present so
    # the oracle can either respect or contrast it against bundle.time_of_day.
    if Array.isArray(source.scene?.time_affinity)
      for seed in anchor_seeds when seed.beat is 'scene'
        seed.time_affinity = source.scene.time_affinity

    M.saveThis 'ingredient_bundle', bundle
    M.saveThis "done:#{stepName}", true
    return
