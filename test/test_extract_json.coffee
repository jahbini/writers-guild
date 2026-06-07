#!/usr/bin/env coffee
###
test/test_extract_json.coffee

Replay the actual broken oracle_brief output (from the user's report)
through the new extractor and report what comes out. No pipeline
required.
###

path = require 'path'
mod = require path.resolve(__dirname, '..', 'scripts/jim/oracle_brief.coffee')

# Surgical: extract just the helpers from the loaded module by
# re-reading and stripping the @step wrapper. Simpler: paste the
# helpers inline here and call them.

# The actual raw MLX output that broke last time:
raw = """
==========
{
  "brief": "Dawn breaks over the harbor, the water still, the lights blinking like slow breaths as I walk the dock, feeling the salt on my skin and the quiet hum of the tide. I step into the town, past the old cafe where Southwick sits, adjusting his glasses with a practiced hand, his eyes sharp as he watches me—something in the way he tilts his head makes me pause. Then, the air thickens: voices rise, not loud, but layered, each one a fragment of memory I can't place, and suddenly the argument feels like a tide pulling back. I follow the sound into the cafe, where the rumors bounce like echoes between the tables, each one catching the light and fading just before it lands. In the stillness after, I realize one lie has been repeated so often it now tastes like the sea breeze—ordinary, inevitable, and somehow more real than truth.",
  "structure_hints": [
    "Dawn: harbor lights blink awake, tide soft, salt on skin",
    "Southwick adjusts glasses, eyes sharp, quiet unease in the air",
    "Voices rise—half-remembered facts fuel a simmering argument",
    "Rumors echo in the cafe, bouncing between tables like dropped pebbles",
    "A lie now feels like the tide—familiar, unremarkable, and unshakable"
  ],
  "transitions": [
    "I walk from the harbor dock to the town edge, the light growing as I step into the street",
    "I enter the cafe and see Southwick at the counter, his gesture pulling me in",
    "The argument begins in the corner booth, and I follow the sound into the back room",
    "I sit at the table, listening as the stories repeat themselves like waves",
    "I realize the lie I once thought strange now feels like the air I breathe"
  ],
  "
==========
Prompt: 409 tokens, 88.270 tokens-per-sec
Generation: 400 tokens, 14.165 tokens-per-sec
Peak memory: 2.761 GB
"""

# Inline the helpers (copied from oracle_brief.coffee) so we test them
# directly without needing to invoke the step's full action.

stripMlxFraming = (text) ->
  cleaned = text
    .replace(/^={5,}\s*\n/, '')
    .replace(/\n={5,}[\s\S]*$/, '')
  cleaned

findBalancedJson = (text) ->
  start = text.indexOf('{')
  return null if start < 0
  depth = 0
  inString = false
  escape = false
  for i in [start...text.length]
    ch = text[i]
    if escape
      escape = false
    else if ch is '\\' and inString
      escape = true
    else if ch is '"'
      inString = !inString
    else if not inString
      if ch is '{'
        depth++
      else if ch is '}'
        depth--
        if depth is 0
          return { json: text[start..i], truncated: false }
  { json: text[start..], truncated: true }

repairTruncatedJson = (text) ->
  depth = 0
  inString = false
  escape = false
  stack = []
  lastSafeEnd = -1
  for i in [0...text.length]
    ch = text[i]
    if escape
      escape = false
    else if ch is '\\' and inString
      escape = true
    else if ch is '"'
      inString = !inString
      lastSafeEnd = i if not inString
    else if not inString
      if ch is '{' or ch is '['
        stack.push ch
      else if ch is '}' or ch is ']'
        stack.pop()
      if /[\s\}\]\d"]/.test(ch)
        lastSafeEnd = i
  head = if lastSafeEnd >= 0 then text[..lastSafeEnd] else text
  head = head.replace(/,\s*"?[A-Za-z_]*\s*:?\s*$/, '')
  head = head.replace(/,\s*$/, '')
  stack.reverse().reduce(((acc, open) ->
    acc + (if open is '{' then '}' else ']')), head)

extractJSON = (text) ->
  cleaned = stripMlxFraming(text)
  found = findBalancedJson(cleaned)
  return null unless found?
  try return JSON.parse(found.json) catch then null
  if found.truncated
    try return JSON.parse(repairTruncatedJson(found.json)) catch then null
  null

parsed = extractJSON(raw)
if parsed?
  console.log "OK — parsed brief object:"
  console.log "  brief: #{(parsed.brief ? '').slice(0, 80)}..."
  console.log "  structure_hints: #{parsed.structure_hints?.length ? 0} items"
  console.log "  transitions:     #{parsed.transitions?.length ? 0} items"
  console.log "  motif_thread:    #{if parsed.motif_thread? then 'present' else 'missing (was truncated)'}"
  console.log "  voice_target:    #{if parsed.voice_target? then 'present' else 'missing (was truncated)'}"
  process.exit 0
else
  console.error "FAIL — extractor returned null"
  process.exit 1
