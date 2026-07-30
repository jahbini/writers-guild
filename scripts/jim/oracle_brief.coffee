@step =
  desc: "Synthesize a unified diary brief from the ingredient bundle"

  action: (S) ->
    bundle = await S.need 'ingredient_bundle'

    beatsBlock = (bundle.anchor_seeds.map (b) ->
      extras = []
      extras.push "location: #{b.location}" if b.location?
      extras.push "character: #{b.character}" if b.character?
      extras.push "motifs: #{b.motifs.join(', ')}" if b.motifs?.length
      tail = if extras.length then "  [#{extras.join(' | ')}]" else ''
      "  - #{b.beat} (#{b.emotion}): #{b.seed}#{tail}").join('\n')

    chars = bundle.characters_in_play.join(', ') or '(none specified)'
    locs  = bundle.locations_in_play.join(', ')  or '(unconstrained)'
    timeStr = bundle.time_of_day or '(let the day suggest its own time)'

    prompt = """
You are a diary-brief composer for the St. John's Jim diary pipeline.
Given the ingredients below, write a single brief (NOT the diary itself)
that another model will use to produce ONE continuous first-person diary
entry threading through five beats in order, with smooth transitions.

Ingredients
-----------
Motif (one-line preoccupation): #{bundle.motif ? '(unspecified)'}
Arc shape: #{bundle.arc_shape} — #{bundle.arc_desc ? ''}
Time of day at opening: #{timeStr}
Characters in play: #{chars}
Locations in play:  #{locs}
Voice: #{bundle.voice_notes}

Beats (preserve this order; the diary must touch each):
#{beatsBlock}

Instructions for the brief
--------------------------
- Each beat must name a CONCRETE ACTION — a verb, a subject, a physical
  change or exchange. Who does what, what gets said, what shifts in the
  room. Description is the setting; action is the substance. The diary
  should TELL A SMALL STORY, not paint five tableaux.
- Anchor the opening to the named time of day; let it evolve plausibly across beats.
- Thread the motif (the curator's preoccupation for this day) through every
  beat without naming it directly.
- Use only the named characters and locations; do not invent proper nouns.
- Specify the transition between each pair of beats (how does the
  narrator get from one to the next? what physical movement, what trigger?).
- Preserve the emotional arc; do not flatten to one tone.

Return JSON of the form:
{
  "brief": "<the unified narrative brief for the generator>",
  "structure_hints": ["<one short line per beat, naming the concrete action: subject + verb + what changes>"],
  "transitions": ["<scene→arrival>", "<arrival→disturbance>", "<disturbance→reflection>", "<reflection→realization>"],
  "motif_thread": "<one-line description of how the motif threads the day>",
  "voice_target": "<one-line voice note>"
}
"""

    # Ledger auto-injects model / max-tokens / temp / top-p / seed from
    # the step's `mlx:` block in override/jim_story.yaml. Body passes prompt only.
    raw = S.callMLX 'generate', { prompt }

    # MLX wraps generation with `==========\n...==========\n` framing and
    # a trailing stats block. Strip both before searching for JSON, and
    # use brace-counting (not greedy regex) to find a balanced object.
    # If the JSON was truncated mid-stream by max_tokens, attempt repair
    # by closing the outstanding strings/arrays/objects.
    stripMlxFraming = (text) ->
      return '' unless typeof text is 'string'
      # Drop the leading `==========\n` line and anything from the
      # closing `\n==========\n` to the end.
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
      # ran off the end — return what we have so the repairer can try
      { json: text[start..], truncated: true }

    # Best-effort repair for a truncated JSON object: close any open
    # string, then close arrays/objects in reverse order. Drops a
    # trailing partial key or value cleanly.
    repairTruncatedJson = (text) ->
      depth = 0
      inString = false
      escape = false
      stack = []  # of '{' or '['
      lastSafeEnd = -1  # index after which we can safely append closers
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
          if ch in [',', ':', '{', '[']
            # ok midway; lastSafeEnd updates on whitespace/closers below
            true
          if /[\s\}\]\d"]/.test(ch) and not inString
            lastSafeEnd = i
      head = if lastSafeEnd >= 0 then text[..lastSafeEnd] else text
      # Trim any trailing comma or partial key like  `, "voice_target`
      head = head.replace(/,\s*"?[A-Za-z_]*\s*:?\s*$/, '')
      head = head.replace(/,\s*$/, '')
      # Close anything left open.
      stack.reverse().reduce(((acc, open) ->
        acc + (if open is '{' then '}' else ']')), head)

    extractJSON = (text) ->
      return null unless text?
      cleaned = stripMlxFraming(text)
      found = findBalancedJson(cleaned)
      return null unless found?
      candidate = found.json
      try return JSON.parse(candidate) catch then null
      # First parse failed — try repair.
      if found.truncated
        try return JSON.parse(repairTruncatedJson(candidate)) catch then null
      null

    parsed = extractJSON(raw)
    brief = parsed ? { brief: raw, parse_error: true }
    brief.motif     = bundle.motif
    brief.arc_shape = bundle.arc_shape

    S.make 'diary_brief', brief
    S.done()
    return
