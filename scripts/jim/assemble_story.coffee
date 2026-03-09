capitalizeFirst = (txt) ->
  sval = String(txt ? '').trim()
  return '' if sval is ''
  sval.charAt(0).toUpperCase() + sval.substring(1)

ensureSentence = (txt) ->
  s = String(txt ? '').trim()
  return '' if s is ''
  if /[.!?]$/.test(s) then s else s + '.'

lowerFirst = (txt) ->
  sval = String(txt ? '').trim()
  return '' if sval is ''
  sval.charAt(0).toLowerCase() + sval.substring(1)

@step =
  desc: "Assemble one Jim story from resolved story parts"

  action: (M, stepName) ->
    parts = await M.need(stepName, 'story_parts')

    sceneText = ensureSentence capitalizeFirst(parts?.scene?.text)
    arrivalText = ensureSentence parts?.arrival?.text
    disturbanceText = ensureSentence capitalizeFirst(parts?.disturbance?.text)
    reflectionText = ensureSentence capitalizeFirst(parts?.reflection?.text)
    realizationText = ensureSentence "That was when I realized #{lowerFirst(parts?.realization?.text)}"

    p1 = "#{sceneText} #{arrivalText}".trim()
    p2 = "#{disturbanceText} #{reflectionText}".trim()
    p3 = realizationText

    storyText = "#{p1}\n\n#{p2}\n\n#{p3}\n"

    out =
      story_id: parts?.story_id
      text: storyText
      parts: parts

    M.put stepName, 'story', out
    M.saveThis "done:#{stepName}", true
    return
