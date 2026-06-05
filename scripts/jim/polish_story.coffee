###
Use LLM to expand and polish assembled story into Jim narrative voice.
###

buildPrompt = (storyText) ->

  prompt = """
You are writing in the narrative voice of Jim from St. John's.

Expand the following story fragment into a short reflective narrative.
Maintain the same events and ideas, but improve flow, imagery, and voice.

Rules:
- Keep the same order of events.
- Do not introduce new plot elements.
- Add natural narration and sensory detail.
- The tone should be observational, slightly humorous, and reflective.
- The final length should be about 800–2000 words.

Story fragment:

#{storyText}

Return only the finished story.
"""

  return prompt


@step =
  desc: "Expand and polish story using LLM"

  action: (M, stepName) ->
    console.log "JIM start", stepName

    storyKey = "story"
    storyEntry = M.theLowdown storyKey
    story = storyEntry?.value
    if story is undefined
      if typeof storyEntry?.waitFor is 'function'
        story = await storyEntry.waitFor()
      else if storyEntry?.notifier?
        story = await storyEntry.notifier
    throw new Error "[#{stepName}] Missing input key '#{storyKey}'" if story is undefined

    baseText = story.text ? ''

    prompt = buildPrompt baseText
    console.log "JIM",prompt
    console.error "JIM",prompt

    # Call model via Memo oracle
    result = await M.oracle stepName,
      prompt: prompt
      temperature: 0.7
      max_tokens: 2000

    polishedText = result?.text ? ''

    out =
      story_id: story.story_id ? null
      text: polishedText
      source_story: story

    M.saveThis "story_polished", out
    M.saveThis "done:#{stepName}", true
    return
