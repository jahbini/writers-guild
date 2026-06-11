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
    # Auto-detects shape: bare list, dict-of-lists, or legacy dict-of-leaves.
    # List items may be either bare strings or objects with `{text, ...extra}`.
    # Extra fields on an object item carry through onto the flattened entry
    # (e.g., time_affinity on a scene).
    processItem = (item, bucketName, makeEntry) ->
      if typeof item is 'string'
        return makeEntry(item, bucketName)
      if item? and typeof item is 'object' and typeof item.text is 'string'
        base = makeEntry(item.text, bucketName)
        for own k, v of item when k isnt 'text'
          base[k] = v
        return base
      null

    flatten = (sourceShelf, makeEntry) ->
      out = {}
      if Array.isArray(sourceShelf)
        for item in sourceShelf
          entry = processItem(item, null, makeEntry)
          continue unless entry?
          key = slug(entry.text, out)
          out[key] = entry
      else if sourceShelf? and typeof sourceShelf is 'object'
        for bucketName, items of sourceShelf
          if Array.isArray(items)
            # dict-of-lists: {harbor: [...], cafe: [...]}
            for item in items
              entry = processItem(item, bucketName, makeEntry)
              continue unless entry?
              key = slug(entry.text, out)
              out[key] = entry
          else if items? and typeof items is 'object' and items.text?
            # legacy dict-of-leaves: {key: {text, ...}}
            entry = { text: items.text }
            entry[k] = v for own k, v of items when k isnt 'text'
            key = slug(entry.text, out)
            out[key] = entry
      out

    flatLibrary =
      scenes: flatten(src.scenes, (text, location) ->
        e = { text }
        e.location = location if location? and location isnt 'unplaced'
        e)

      characters: flatten(src.characters, (gesture, name) ->
        # Reconstruct the full sentence by prepending the character name.
        full = if name? then "#{name} #{gesture}" else gesture
        { text: full, character: name })

      disturbances: flatten(src.disturbances, (text, theme) ->
        e = { text }
        e.theme = theme if theme? and theme isnt 'untagged'
        e)

      reflections: flatten(src.reflections, (text, family) ->
        e = { text }
        e.family = family if family?
        e)

      realizations: flatten(src.realizations, (text, family) ->
        e = { text }
        e.family = family if family?
        e)

    # ─── recipe_defaults: resolve literal-text beat refs to flat keys ──
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

    resolvedDefaults = {}
    for own k, v of (doc?.recipe_defaults ? {})
      resolvedDefaults[k] = v
    for beat, shelfName of beatShelf
      ref = resolvedDefaults[beat]
      continue unless ref?
      if textIndex[shelfName][ref]?
        resolvedDefaults[beat] = textIndex[shelfName][ref]
      else unless flatLibrary[shelfName][ref]?
        console.warn "[#{stepName}] recipe_defaults.#{beat} = '#{ref}' not found in #{shelfName}"

    out =
      source_file: libraryPath
      library: flatLibrary
      arc_shapes: doc?.arc_shapes ? {}
      recipe_defaults: resolvedDefaults

    M.saveThis "story_library", out
    M.saveThis "done:#{stepName}", true
    return
