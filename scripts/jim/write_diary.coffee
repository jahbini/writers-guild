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

timestamp = ->
  d = new Date()
  "#{d.getFullYear()}-#{pad2(d.getMonth()+1)}-#{pad2(d.getDate())}_#{pad2(d.getHours())}-#{pad2(d.getMinutes())}-#{pad2(d.getSeconds())}"

@step =
  desc: "Write a consolidated diary YAML to diary/ per run"

  action: (M, stepName) ->
    bundle = M.theLowdown('ingredient_bundle')?.value
    brief  = M.theLowdown('diary_brief')?.value
    parts  = M.theLowdown('story_parts')?.value
    recipe = M.theLowdown('story_recipe')?.value

    throw new Error "[#{stepName}] ingredient_bundle missing"  unless bundle?
    throw new Error "[#{stepName}] diary_brief missing"        unless brief?

    cwdDir = M.theLowdown('env/CWD')?.value ? process.cwd()
    recipeName = M.getStepParam(stepName, 'recipe_name') ? 'jim_story'

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
      oracle_brief: brief

    # Echo selected per-beat overrides for traceability.
    if recipe?.overrides?.length
      doc.recipe_overrides = recipe.overrides

    diaryDir = path.join(cwdDir, 'diary')
    fs.mkdirSync(diaryDir, recursive: true) unless fs.existsSync(diaryDir)

    filename = "#{recipeName}_#{timestamp()}.yaml"
    outPath = path.join(diaryDir, filename)
    fs.writeFileSync outPath, yaml.dump(doc, { lineWidth: -1, noRefs: true }), 'utf8'
    console.log "[#{stepName}] wrote #{outPath}"

    M.saveThis 'diary_file', outPath
    M.saveThis "done:#{stepName}", true
    return
