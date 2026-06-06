###
load_library.coffee

Reads the clean editing-surface schema in data/jim_story_library.yaml
and flattens it into the keyed-dict shape that downstream steps
(select_story_recipe, resolve_story_parts) still consume.

Editing schema (on disk):
  library:
    scenes:        <location>: [ "<full sentence>", … ]
    characters:    <Name>:     [ "<bare gesture>", … ]
    disturbances:  <theme>:    [ "<full sentence>", … ]
    reflections:   [ "<full sentence>", … ]
    realizations:  [ "<full sentence>", … ]
  arc_shapes: { … }
  stories:    { <id>: { motif, arc_shape, …, scene/arrival/.../realization: <literal text> } }

Runtime artifact (in memo) — the old shape downstream expects:
  story_library:
    source_file: <path>
    library:
      scenes:        <key>: { text, location }
      characters:    <key>: { text, character }
      disturbances:  <key>: { text, theme }
      reflections:   <key>: { text }
      realizations:  <key>: { text }
    arc_shapes: { … }                  # carried through unchanged
    stories:    { <id>: { …, scene: <key>, arrival: <key>, … } }
###

fs   = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

@step =
  desc: "Load library YAML (clean schema) and flatten into runtime shape"

  action: (M, stepName) ->
    console.log "JIM start", stepName
    libraryFile = M.getStepParam(stepName, 'library_file') ? 'data/jim_story_library.yaml'

    execDir = M.theLowdown('env/EXEC')?.value ? process.cwd()
    cwdDir  = M.theLowdown('env/CWD')?.value  ? process.cwd()
    resolveInputPath = (p) ->
      return null unless typeof p is 'string' and p.length > 0
      return p if path.isAbsolute(p)
      fromCwd  = path.resolve(cwdDir,  p)
      return fromCwd  if fs.existsSync(fromCwd)
      fromExec = path.resolve(execDir, p)
      return fromExec if fs.existsSync(fromExec)
      fromCwd  # report the cwd path on miss

    libraryPath = resolveInputPath(libraryFile)
    unless libraryPath? and fs.existsSync(libraryPath)
      throw new Error "[#{stepName}] Missing library_file: #{libraryFile} (resolved: #{libraryPath})"

    raw = fs.readFileSync libraryPath, 'utf8'
    doc = yaml.load(raw)

    src = doc?.library
    unless src?
      throw new Error "[#{stepName}] Library YAML missing top-level 'library'"

    # ─── slug helper: match existing key format ───────────────────────
    # lowercase, strip non-ASCII, non-alphanum → _, collapse, trim,
    # truncate to 48 chars. Collisions get _2, _3, ….
    used = {}
    slug = (text, shelfKeys) ->
      s = text.toLowerCase()
        .replace(/[^\x00-\x7f]/g, '')
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/_+/g, '_')
        .replace(/^_|_$/g, '')
        .slice(0, 48)
        .replace(/_$/, '')
      s = 'untitled' if s.length is 0
      base = s
      n = 2
      while shelfKeys[s]?
        s = "#{base}_#{n}"
        n += 1
      s

    # ─── flatten each shelf ────────────────────────────────────────────
    flatten = (sourceShelf, makeEntry, isGrouped) ->
      out = {}
      if isGrouped
        # dict-of-lists: {harbor: [...], cafe: [...]}
        for bucketName, items of (sourceShelf ? {})
          continue unless Array.isArray(items)
          for item in items
            entry = makeEntry(item, bucketName)
            key = slug(entry.text, out)
            out[key] = entry
      else
        # bare list: [...]
        for item in (sourceShelf ? [])
          entry = makeEntry(item, null)
          key = slug(entry.text, out)
          out[key] = entry
      out

    flatLibrary =
      scenes: flatten(src.scenes, ((text, location) ->
        e = { text }
        e.location = location if location? and location isnt 'unplaced'
        e), true)

      characters: flatten(src.characters, ((gesture, name) ->
        # Reconstruct the full sentence by prepending the character name.
        full = if name? then "#{name} #{gesture}" else gesture
        { text: full, character: name }), true)

      disturbances: flatten(src.disturbances, ((text, theme) ->
        e = { text }
        e.theme = theme if theme? and theme isnt 'untagged'
        e), true)

      reflections:  flatten(src.reflections,  ((text) -> { text }), false)
      realizations: flatten(src.realizations, ((text) -> { text }), false)

    # ─── stories: resolve literal-text beat refs to flat keys ─────────
    beatShelf = {
      scene:       'scenes'
      arrival:     'characters'
      disturbance: 'disturbances'
      reflection:  'reflections'
      realization: 'realizations'
    }

    # Build reverse index: text → key, per shelf
    textIndex = {}
    for shelfName, entries of flatLibrary
      textIndex[shelfName] = {}
      for k, v of entries
        textIndex[shelfName][v.text] = k

    resolvedStories = {}
    for storyId, story of (doc?.stories ? {})
      copy = {}
      for k, v of story
        copy[k] = v
      for beat, shelfName of beatShelf
        ref = story[beat]
        continue unless ref?
        # Accept either the literal text or an already-flat key.
        if textIndex[shelfName][ref]?
          copy[beat] = textIndex[shelfName][ref]
        else if flatLibrary[shelfName][ref]?
          # already a flat key
          copy[beat] = ref
        else
          console.warn "[#{stepName}] story #{storyId}.#{beat} = '#{ref}' not found in #{shelfName}"
          copy[beat] = ref
      resolvedStories[storyId] = copy

    out =
      source_file: libraryPath
      library: flatLibrary
      arc_shapes: doc?.arc_shapes ? {}
      stories: resolvedStories

    M.saveThis "story_library", out
    M.saveThis "done:#{stepName}", true
    return
