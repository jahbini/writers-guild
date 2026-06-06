#!/usr/bin/env coffee
###
test/recategorize_library.coffee

One-shot: re-bucket disturbances, reflections, and realizations into
multiple sub-categories so the UI accordion has meaningful groups to
collapse (matching the multi-bucket shape that scenes/characters
already have).

Buckets are assigned by keyword matching against the text. Anything
that doesn't match falls into "other" — the curator can re-home those
by hand later.

Writes data/jim_story_library.yaml.new for inspection; rename over the
original once happy.
###

fs   = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

REPO_ROOT = path.resolve(__dirname, '..')
src = yaml.load fs.readFileSync(path.join(REPO_ROOT, 'data/jim_story_library.yaml'), 'utf8')

# ─── bucket rules: ordered list of (bucket, regex) pairs ─────────────
# First match wins. Order matters — put more-specific rules first.

DISTURBANCE_RULES = [
  ['media',         /(online|radio|television|tv|video clips?|social media|messaging apps?|short messages?|copied posts|streaming|broadcast)/i]
  ['fear',          /\b(fear|afraid|warning|disaster|panic|scared|terror)\b/i]
  ['outrage',       /(anger|argu|outrage|escalat|hostility|fury|insult|provoke|divide|attack)/i]
  ['rumor',         /(rumor|gossip|conspirac|myth|whisper|exaggerat)/i]
  ['identity',      /(identity|loyalty|belief|defending|defend|tribe|group|in.group)/i]
  ['repetition',    /(repeat|repetition|recycled|same\b|over and over|again and again|copies?|forward(ing)?\b|circulat)/i]
  ['credulity',     /(believ|trust|quote|repeat experts|authority|statistic|number|witness|forward)/i]
]

REFLECTION_RULES = [
  ['water',         /(fog|sea|mist|harbor|river|tide|water|wave|ripple|drift|seaweed|buoy)/i]
  ['fire and light',/(electric|spark|fire|wildfire|burn|flicker|lighthouse|dawn|light|flint)/i]
  ['weather',       /(storm|snow|wind|ice|winter|cloud|rain|gale)/i]
  ['growth',        /(root|weed|algae|ivy|bloom|grow|season|migrat|bird|flower)/i]
  ['structure',     /(brick|stack|map|stone|anchor|construct|build|driftwood|treasure)/i]
  ['motion and sound',/(echo|bell|hum|noise|engine|wave|smoke|crawl|circle|gull)/i]
]

REALIZATION_RULES = [
  ['noticing',      /(notice|notic|observ|attention|wisdom begins|begin)/i]
  ['fear',          /\b(fear|afraid|imagination)\b/i]
  ['repetition',    /(repeat|repetition|habit|familiar|borrowed|history)/i]
  ['crowd',         /(crowd|people|most|everyone|identity|group|culture|society|human)/i]
  ['truth',         /(truth|accuracy|reality|wisdom|patient|simple|whisper|small|understanding)/i]
  ['noise',         /(noise|loud|drama|exaggerat|anger|burns?|argument)/i]
]

bucketize = (entries, rules, defaultName = 'other') ->
  buckets = {}
  for text in entries
    placed = false
    for [name, re] in rules
      if re.test(text)
        buckets[name] ?= []
        buckets[name].push text
        placed = true
        break
    unless placed
      buckets[defaultName] ?= []
      buckets[defaultName].push text
  buckets

# ─── flatten current shape into bare lists ───────────────────────────
# disturbances is currently {mind_worm: [...]} — take that one list.
flattenDisturbances = ->
  out = []
  for own _theme, items of (src.library.disturbances ? {})
    out = out.concat(items) if Array.isArray(items)
  out

disturbances  = bucketize(flattenDisturbances(),       DISTURBANCE_RULES, 'other')
reflections   = bucketize(src.library.reflections ? [], REFLECTION_RULES, 'other')
realizations  = bucketize(src.library.realizations ? [], REALIZATION_RULES, 'other')

# Sort entries alphabetically within each bucket for readable diffs.
for _bucket, items of disturbances
  items.sort()
for _bucket, items of reflections
  items.sort()
for _bucket, items of realizations
  items.sort()

# ─── reassemble doc, preserving scenes/characters/arc_shapes/stories ─
outDoc =
  library:
    scenes:        src.library.scenes
    characters:    src.library.characters
    disturbances:  disturbances
    reflections:   reflections
    realizations:  realizations
  arc_shapes: src.arc_shapes
  stories:    src.stories

outPath = path.join(REPO_ROOT, 'data/jim_story_library.yaml.new')
fs.writeFileSync outPath, yaml.dump(outDoc, { lineWidth: -1, noRefs: true }), 'utf8'

console.log "wrote #{outPath}\n"
report = (label, b) ->
  console.log "#{label}:"
  pairs = ([k, v.length] for k, v of b)
  pairs.sort (a, b) -> b[1] - a[1]
  for [k, n] in pairs
    console.log "  #{k.padEnd(20)} #{n}"
  console.log ''
report 'disturbances', disturbances
report 'reflections',  reflections
report 'realizations', realizations
