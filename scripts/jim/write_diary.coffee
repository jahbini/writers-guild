###
write_diary.coffee

Consolidates the recipe's outputs (story_recipe, story_parts,
ingredient_bundle, diary_brief) into one self-contained YAML and
writes it to diary/<recipe>_<timestamp>.yaml, where the UI's Diary
Files panel surfaces it as a new item per run.
###

fs   = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

pad2 = (n) -> (if n < 10 then '0' else '') + n

# Short tag: HH_MM. Runs in the same minute will overwrite.
runTag = ->
  d = new Date()
  "#{pad2(d.getHours())}_#{pad2(d.getMinutes())}"

@step =
  desc: "Write a consolidated diary YAML to diary/ per run"

  action: (M, stepName) ->
    cwdDir = M.theLowdown('env/CWD')?.value ? process.cwd()
    recipeName = M.getStepParam(stepName, 'recipe_name') ? 'jim_story'

    # Read the artifacts from disk rather than the memo. The disk files
    # are what oracle_brief / assemble_ingredients actually wrote this
    # run; the memo can drift under specific resume/wiring conditions.
    readDiskJson = (relPath) ->
      abs = path.join(cwdDir, relPath)
      return null unless fs.existsSync(abs)
      try JSON.parse(fs.readFileSync(abs, 'utf8')) catch then null

    bundle = readDiskJson('out/ingredient_bundle.json')  \
      ? M.theLowdown('ingredient_bundle')?.value
    brief  = readDiskJson('out/diary_brief.json')        \
      ? M.theLowdown('diary_brief')?.value
    recipe = readDiskJson('out/story_recipe.json')       \
      ? M.theLowdown('story_recipe')?.value

    throw new Error "[#{stepName}] ingredient_bundle missing"  unless bundle?
    throw new Error "[#{stepName}] diary_brief missing"        unless brief?

    # Build the per-beat block from the bundle's anchor_seeds so the
    # diary file is readable without cross-referencing the library.
    beats = {}
    for seed in (bundle.anchor_seeds ? [])
      blk =
        emotion: seed.emotion
        seed: seed.seed
      blk.location  = seed.location  if seed.location?
      blk.character = seed.character if seed.character?
      blk.theme     = seed.theme     if seed.theme?
      beats[seed.beat] = blk

    # Surface the brief content at the top level so it's the first
    # thing a reader sees, regardless of what shape oracle_brief
    # returned (clean JSON, raw text fallback, or something odd).
    briefText      = brief?.brief
    structureHints = brief?.structure_hints
    transitions    = brief?.transitions
    motifThread    = brief?.motif_thread
    voiceTarget    = brief?.voice_target

    doc =
      generated_at: new Date().toISOString()
      recipe: recipeName
      story_id: bundle.story_id
      motif: bundle.motif
      arc_shape: bundle.arc_shape
      arc_desc: bundle.arc_desc
      voice_notes: bundle.voice_notes
      characters_in_play: bundle.characters_in_play
      locations_in_play:  bundle.locations_in_play
      beats: beats

    doc.brief            = briefText      if briefText?
    doc.structure_hints  = structureHints if structureHints?
    doc.transitions      = transitions    if transitions?
    doc.motif_thread     = motifThread    if motifThread?
    doc.voice_target     = voiceTarget    if voiceTarget?
    doc.oracle_brief_raw = brief          # full payload for inspection

    # Echo selected per-beat overrides for traceability.
    if recipe?.overrides?.length
      doc.recipe_overrides = recipe.overrides

    diaryDir = path.join(cwdDir, 'diary')
    fs.mkdirSync(diaryDir, recursive: true) unless fs.existsSync(diaryDir)

    filename = "#{recipeName}_#{runTag()}.yaml"
    outPath = path.join(diaryDir, filename)
    fs.writeFileSync outPath, yaml.dump(doc, { lineWidth: -1, noRefs: true }), 'utf8'
    console.log "[#{stepName}] wrote #{outPath}"

    M.saveThis 'diary_file', outPath
    M.saveThis "done:#{stepName}", true
    return
