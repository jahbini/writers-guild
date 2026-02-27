###
Compose a prompt for story generation using Four Forces ontology
###

exports.composePrompt = (profiles, interaction, tarotCue, onto) ->
  lines = []
  lines.push "SYSTEM: You are a co-author using the Four Forces ontology (Logos, Ethos, Pathos, Anima)."
  lines.push "Honor tarot cue: #{tarotCue}."
  lines.push ""
  lines.push "CHARACTER ENERGIES:"
  for name, prof of profiles
    desc = []
    for axis, obj of prof when typeof obj is 'object'
      desc.push "#{axis}: #{obj.score?.toFixed?(2) ? '0.0'} (#{obj.keyword})"
    lines.push "- #{name}: #{desc.join(', ')}"
  lines.push ""
  lines.push "INTERACTION: #{interaction}"
  lines.push ""
  lines.push "STYLE: Maintain tone consistent with #{tarotCue}."
  return lines.join '\n'
