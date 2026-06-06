@step =
  desc: "Synthesize a unified diary brief from the ingredient bundle"

  action: (M, stepName) ->
    bundle = M.theLowdown('ingredient_bundle').value
    throw new Error "[#{stepName}] ingredient_bundle missing from memo" unless bundle?

    modelId = M.getStepParam stepName, 'model'
    maxTok  = M.getStepParam(stepName, 'max_tokens') ? 1024
    throw new Error "[#{stepName}] Missing 'model' param" unless modelId?

    beatsBlock = (bundle.anchor_seeds.map (b) ->
      extras = []
      extras.push "location: #{b.location}" if b.location?
      extras.push "character: #{b.character}" if b.character?
      extras.push "motifs: #{b.motifs.join(', ')}" if b.motifs?.length
      tail = if extras.length then "  [#{extras.join(' | ')}]" else ''
      "  - #{b.beat} (#{b.emotion}): #{b.seed}#{tail}").join('\n')

    chars = bundle.characters_in_play.join(', ') or '(none specified)'
    locs  = bundle.locations_in_play.join(', ')  or '(unconstrained)'

    prompt = """
You are a diary-brief composer for the St. John's Jim diary pipeline.
Given the ingredients below, write a single brief (NOT the diary itself)
that another model will use to produce ONE continuous first-person diary
entry threading through five beats in order, with smooth transitions.

Ingredients
-----------
Motif: #{bundle.motif ? '(unspecified)'}
Arc shape: #{bundle.arc_shape} — #{bundle.arc_desc ? ''}
Characters in play: #{chars}
Locations in play:  #{locs}
Voice: #{bundle.voice_notes}

Beats (preserve this order; the diary must touch each):
#{beatsBlock}

Instructions for the brief
--------------------------
- Establish time of day at the start and let it evolve plausibly across beats.
- Thread the motif through every beat without naming it directly.
- Use only the named characters and locations; do not invent proper nouns.
- Specify the transition between each pair of beats (how does the
  narrator get from one to the next?).
- Preserve the emotional arc; do not flatten to one tone.

Return JSON of the form:
{
  "brief": "<the unified narrative brief for the generator>",
  "structure_hints": ["<one short line per beat in order>"],
  "transitions": ["<scene→arrival>", "<arrival→disturbance>", "<disturbance→reflection>", "<reflection→realization>"],
  "motif_thread": "<one-line description of how the motif threads the day>",
  "voice_target": "<one-line voice note>"
}
"""

    raw = M.callMLX 'generate',
      model: modelId
      prompt: prompt
      'max-tokens': maxTok

    extractJSON = (text) ->
      return null unless text?
      blk = text.match(/\{[\s\S]*\}/)?[0]
      return null unless blk?
      try JSON.parse(blk) catch then null

    brief = extractJSON(raw) ? { brief: raw, parse_error: true }
    brief.story_id  = bundle.story_id
    brief.motif     = bundle.motif
    brief.arc_shape = bundle.arc_shape

    M.saveThis 'diary_brief', brief
    M.saveThis "done:#{stepName}", true
    return
