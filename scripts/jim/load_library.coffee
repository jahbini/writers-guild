fs = require 'fs'
yaml = require 'js-yaml'

@step =
  desc: "Load keyed Jim story library YAML"

  action: (M, stepName) ->
    libraryFile = M.getStepParam(stepName, 'library_file') ? 'data/jim_story_library.yaml'

    unless fs.existsSync libraryFile
      throw new Error "[#{stepName}] Missing library_file: #{libraryFile}"

    raw = fs.readFileSync libraryFile, 'utf8'
    doc = yaml.load(raw)

    unless doc?.library?
      throw new Error "[#{stepName}] Library YAML missing top-level 'library'"
    unless doc?.stories?
      throw new Error "[#{stepName}] Library YAML missing top-level 'stories'"

    out =
      source_file: libraryFile
      library: doc.library
      stories: doc.stories

    M.put stepName, 'story_library', out
    M.saveThis "done:#{stepName}", true
    return
