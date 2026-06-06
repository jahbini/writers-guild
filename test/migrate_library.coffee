#!/usr/bin/env coffee
###
test/migrate_library.coffee

One-shot conversion from the old flat-keyed library shape to the new
list-based shape, with arc_shapes merged in and stories carrying
literal text per beat. Writes data/jim_story_library.yaml.new for
inspection; rename it over the original after verifying.

Schema convention (post-migration):
  library:
    scenes:        <location>: [ "<full sentence>", … ]
    characters:    <Name>:     [ "<bare gesture>", … ]    # load_library prepends name
    disturbances:  <theme>:    [ "<full sentence>", … ]
    reflections:   [ "<full sentence>", … ]               # bare list
    realizations:  [ "<full sentence>", … ]               # bare list
  arc_shapes:
    <name>: { desc, emotions: [5] }
  stories:
    <id>: { motif, arc_shape, characters_in_play, locations_in_play,
            voice_notes, scene, arrival, disturbance, reflection, realization }
###

fs   = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

REPO_ROOT = path.resolve(__dirname, '..')

oldLib  = yaml.load fs.readFileSync(path.join(REPO_ROOT, 'data/jim_story_library.yaml'), 'utf8')
oldArcs = yaml.load fs.readFileSync(path.join(REPO_ROOT, 'data/arc_shapes.yaml'),       'utf8')

# ─── helpers ────────────────────────────────────────────────────────
# Map old flat key → text from each shelf, so stories can resolve.
textForKey = {}
for shelf in ['scenes','characters','disturbances','reflections','realizations']
  for k, v of (oldLib.library?[shelf] ? {})
    textForKey["#{shelf}|#{k}"] = v.text

# Strip the character name from the beginning of a gesture sentence.
# "Southwick folds his newspaper carefully" + "Southwick" → "folds his newspaper carefully"
stripName = (text, name) ->
  return text unless name?
  if text.toLowerCase().startsWith(name.toLowerCase() + ' ')
    text[name.length + 1 ..]
  else
    text  # leave as-is if pattern doesn't match

# ─── scenes: group by location ──────────────────────────────────────
scenes = {}
for k, v of (oldLib.library.scenes ? {})
  loc = v.location ? 'unplaced'
  scenes[loc] ?= []
  scenes[loc].push v.text

# ─── characters: group by character name, store bare gestures ───────
characters = {}
for k, v of (oldLib.library.characters ? {})
  name = v.character ? 'unnamed'
  characters[name] ?= []
  characters[name].push stripName(v.text, name)

# ─── disturbances: group by theme ───────────────────────────────────
disturbances = {}
for k, v of (oldLib.library.disturbances ? {})
  theme = v.theme ? 'untagged'
  disturbances[theme] ?= []
  disturbances[theme].push v.text

# ─── reflections + realizations: bare lists ─────────────────────────
reflections  = (v.text for k, v of (oldLib.library.reflections  ? {}))
realizations = (v.text for k, v of (oldLib.library.realizations ? {}))

# ─── stories: rewrite beat refs as literal text ─────────────────────
stories = {}
for id, story of (oldLib.stories ? {})
  rewritten =
    motif: story.motif ? null
    arc_shape: story.arc_shape ? 'st_johns_standard'
    characters_in_play: story.characters_in_play ? []
    locations_in_play:  story.locations_in_play  ? []
    voice_notes: story.voice_notes ? "St. John's diary, first-person, sensory-dense"
  for beat, shelfName of {
    scene:       'scenes',
    arrival:     'characters',
    disturbance: 'disturbances',
    reflection:  'reflections',
    realization: 'realizations'
  }
    refKey = story[beat]
    resolved = textForKey["#{shelfName}|#{refKey}"] ? refKey
    rewritten[beat] = resolved
  # drop null metadata for stories that didn't have them
  delete rewritten[k] for k of rewritten when rewritten[k] is null
  stories[id] = rewritten

# ─── arc_shapes: lift in from the separate file ─────────────────────
arcShapes = oldArcs.arc_shapes ? {}

# ─── assemble + write ───────────────────────────────────────────────
outDoc =
  library:
    scenes:        scenes
    characters:    characters
    disturbances:  disturbances
    reflections:   reflections
    realizations:  realizations
  arc_shapes: arcShapes
  stories:    stories

# js-yaml preserves insertion order for plain objects.
outPath = path.join(REPO_ROOT, 'data/jim_story_library.yaml.new')
fs.writeFileSync outPath, yaml.dump(outDoc, { lineWidth: -1, noRefs: true }), 'utf8'
console.log "wrote #{outPath}"
console.log "  scenes locations:     #{Object.keys(scenes).join(', ')}"
console.log "  character buckets:    #{Object.keys(characters).join(', ')}"
console.log "  disturbance themes:   #{Object.keys(disturbances).join(', ')}"
console.log "  reflections count:    #{reflections.length}"
console.log "  realizations count:   #{realizations.length}"
console.log "  arc shapes:           #{Object.keys(arcShapes).join(', ')}"
console.log "  stories:              #{Object.keys(stories).join(', ')}"
