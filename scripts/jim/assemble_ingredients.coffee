fs   = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

@step =
  desc: "Assemble ingredient bundle for the oracle composer"

  action: (M, stepName) ->
    storyId        = M.getStepParam stepName, 'story_id'
    arcShapesFile  = M.getStepParam(stepName, 'arc_shapes_file') ? 'data/arc_shapes.yaml'

    library = M.theLowdown('story_library').value
    throw new Error "[#{stepName}] story_library missing from memo" unless library?

    storyDef = library.stories?[storyId]
    throw new Error "[#{stepName}] Unknown story_id #{storyId}" unless storyDef?

    execDir = M.theLowdown('env/EXEC')?.value ? process.cwd()
    cwdDir  = M.theLowdown('env/CWD')?.value  ? process.cwd()
    resolveInputPath = (p) ->
      return p if path.isAbsolute(p)
      candidate = path.resolve(cwdDir, p)
      return candidate if fs.existsSync(candidate)
      path.resolve(execDir, p)

    arcDoc = yaml.load fs.readFileSync(resolveInputPath(arcShapesFile), 'utf8')
    arcShapes = arcDoc.arc_shapes ? {}
    arcShape  = arcShapes[storyDef.arc_shape]
    throw new Error "[#{stepName}] Unknown arc_shape #{storyDef.arc_shape}" unless arcShape?
    unless Array.isArray(arcShape.emotions) and arcShape.emotions.length is 5
      throw new Error "[#{stepName}] arc_shape #{storyDef.arc_shape} must list exactly 5 emotions"

    beats = ['scene','arrival','disturbance','reflection','realization']
    bucketFor = (beat) ->
      switch beat
        when 'arrival' then 'characters'
        else "#{beat}s"

    # Deterministic index from storyId + beat name
    hashIdx = (s, n) ->
      h = 0
      for ch in s
        h = (h * 31 + ch.charCodeAt(0)) | 0
      ((h % n) + n) % n

    pickEntry = (beat, emotion) ->
      bucket = library.library?[bucketFor(beat)] ? {}
      # 1. explicit override on the story entry wins
      if storyDef[beat]? and bucket[storyDef[beat]]?
        return [storyDef[beat], bucket[storyDef[beat]]]
      # 2. filter by motif + emotion_affinity (both optional / backward compatible)
      motif = storyDef.motif
      keys = (k for k, v of bucket when \
        (not motif? or not v.motifs? or v.motifs.includes(motif)) and \
        (not emotion? or not v.emotion_affinity? or v.emotion_affinity.includes(emotion)))
      # 3. if filter wiped everything, fall back to all entries
      keys = (k for k of bucket) if keys.length is 0
      throw new Error "[#{stepName}] no candidates for beat #{beat}" if keys.length is 0
      keys.sort()
      key = keys[hashIdx("#{storyId}|#{beat}", keys.length)]
      [key, bucket[key]]

    anchor_seeds = for beat, i in beats
      emotion = arcShape.emotions[i]
      [key, entry] = pickEntry(beat, emotion)
      seed =
        beat: beat
        key: key
        seed: entry.text
        emotion: emotion
      seed.location   = entry.location  if entry.location?
      seed.character  = entry.character if entry.character?
      seed.theme      = entry.theme     if entry.theme?
      seed.motifs     = entry.motifs    if entry.motifs?
      seed

    bundle =
      story_id: storyId
      motif: storyDef.motif ? null
      arc_shape: storyDef.arc_shape
      arc_desc: arcShape.desc ? null
      characters_in_play: storyDef.characters_in_play ? []
      locations_in_play:  storyDef.locations_in_play  ? []
      voice_notes: storyDef.voice_notes ? "St. John's diary, first-person, sensory-dense"
      anchor_seeds: anchor_seeds

    M.saveThis 'ingredient_bundle', bundle
    M.saveThis "done:#{stepName}", true
    return
