###
Deterministic plot + character extractor for a series of stories.
Outputs audit-first structures aligned with plot_character.yaml analysis_output.
###

fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
{ spawnSync } = require 'child_process'

EXEC = path.resolve(process.env.EXEC ? path.join(__dirname, '..'))
PWD = path.resolve(process.env.PWD ? process.cwd())

sha256 = (s) ->
  crypto.createHash('sha256').update(String(s)).digest('hex')

hashId = (prefix, parts...) ->
  "#{prefix}_#{sha256(parts.join('|')).slice(0, 16)}"

sortById = (arr) ->
  arr.slice().sort (a, b) -> String(a?.id ? '').localeCompare(String(b?.id ? ''))

sortStrings = (arr) ->
  arr.slice().sort (a, b) -> String(a).localeCompare(String(b))

stableStringify = (obj) ->
  normalize = (v) ->
    if Array.isArray(v)
      return (normalize(x) for x in v)
    if v? and typeof v is 'object'
      out = {}
      for k in Object.keys(v).sort()
        out[k] = normalize(v[k])
      return out
    v
  JSON.stringify(normalize(obj))

isUnderRoot = (fullPath, rootPath) ->
  rel = path.relative(rootPath, fullPath)
  rel is '' or (not rel.startsWith('..') and not path.isAbsolute(rel))

resolveInputPath = (p) ->
  throw new Error "Input path must be non-empty string" unless typeof p is 'string' and p.length > 0

  if path.isAbsolute(p)
    abs = path.resolve(p)
    unless isUnderRoot(abs, PWD) or isUnderRoot(abs, EXEC)
      throw new Error "Input path must resolve under PWD or EXEC: #{p}"
    return abs

  fromPwd = path.resolve(PWD, p)
  return fromPwd if fs.existsSync(fromPwd)

  fromExec = path.resolve(EXEC, p)
  return fromExec if fs.existsSync(fromExec)

  throw new Error "Input path not found under PWD or EXEC: #{p}"

resolveOutputPath = (p) ->
  throw new Error "Output path must be non-empty string" unless typeof p is 'string' and p.length > 0
  abs = if path.isAbsolute(p) then path.resolve(p) else path.resolve(PWD, p)
  throw new Error "Output path must be under PWD: #{p}" unless isUnderRoot(abs, PWD)
  abs

gitCommitHash = ->
  try
    result = spawnSync 'git', ['-C', EXEC, 'rev-parse', 'HEAD'], encoding: 'utf8'
    if result.status is 0 then result.stdout.trim() else 'unknown'
  catch
    'unknown'

createLogger = (stepName, executionParams) ->
  logDir = path.join(PWD, 'logs')
  fs.mkdirSync(logDir, { recursive: true })
  logPath = path.join(logDir, "#{stepName}.log")

  write = (level, msg) ->
    ts = new Date().toISOString()
    fs.appendFileSync(logPath, "[#{ts}] [#{level}] #{msg}\n", 'utf8')

  write('INFO', "start step=#{stepName}")
  write('INFO', "git_commit=#{gitCommitHash()}")
  write('INFO', "exec=#{EXEC}")
  write('INFO', "pwd=#{PWD}")
  write('INFO', "params=#{JSON.stringify(executionParams)}")

  {
    info: (msg) -> write('INFO', msg)
    error: (msg) -> write('ERROR', msg)
    close: (status) -> write('INFO', "end status=#{status}")
  }

toEvidence = (sourceId, sourceText, startChar, endChar) ->
  start = Math.max(0, startChar ? 0)
  stop = Math.max(start, endChar ? start)
  quote = sourceText.slice(start, stop).trim()
  {
    source_id: sourceId
    start_char: start
    end_char: stop
    quote: quote.slice(0, 180)
  }

# Scan text left-to-right and produce authoritative offsets for non-empty paragraphs.
splitParagraphs = (text) ->
  out = []
  i = 0
  n = text.length

  isLineBreak = (c) -> c is '\n' or c is '\r'
  isWhitespace = (c) -> c is ' ' or c is '\t' or isLineBreak(c)

  while i < n
    while i < n and isWhitespace(text[i])
      i += 1
    break if i >= n

    pStart = i
    sawBlankLine = false
    while i < n
      if isLineBreak(text[i])
        j = i
        while j < n and isLineBreak(text[j])
          j += 1
        k = j
        while k < n and (text[k] is ' ' or text[k] is '\t')
          k += 1
        if k < n and isLineBreak(text[k])
          sawBlankLine = true
          i = k + 1
          break
      i += 1

    pStop = if sawBlankLine then i else n
    while pStop > pStart and isWhitespace(text[pStop - 1])
      pStop -= 1

    if pStop > pStart
      out.push
        text: text.slice(pStart, pStop)
        start: pStart
        stop: pStop

  out.sort (a, b) -> a.start - b.start

inferCharacters = (text) ->
  counts = {}
  for m in text.match(/\b[A-Z][a-z]{2,}\b/g) ? []
    counts[m] = (counts[m] ? 0) + 1

  Object.keys(counts)
    .filter (n) -> counts[n] >= 2
    .sort (a, b) ->
      diff = counts[b] - counts[a]
      return diff if diff isnt 0
      a.localeCompare(b)
    .slice(0, 6)

mkCharacter = (storyRef, name) ->
  {
    id: hashId('ch', storyRef, name.trim().toLowerCase())
    display_name: name
    role:
      primary: "actor"
      notes: "auto-extracted seed"
    identity:
      tags: []
    typing:
      enneagram:
        type_id: "unknown"
        wing: "unknown"
        instinct: "unknown"
        confidence: 0.0
        evidence_spans: []
      tarot_profile:
        dominant_suit_id: "unknown"
        secondary_suit_id: "unknown"
        confidence: 0.0
        evidence_spans: []
    drivers:
      desire:
        statement: "unknown"
        candidates: []
        confidence: 0.0
        evidence_spans: []
      fear:
        statement: "unknown"
        candidates: []
        confidence: 0.0
        evidence_spans: []
      belief:
        statement: "unknown"
        candidates: []
        confidence: 0.0
        evidence_spans: []
    patterns:
      mask:
        statement: "unknown"
        candidates: []
        confidence: 0.0
        evidence_spans: []
      wound:
        trigger_pattern: "unknown"
        response_pattern: "unknown"
        candidates: []
        confidence: 0.0
        evidence_spans: []
    capacities:
      resources: []
      skills: []
      authority: []
      constraints: []
    relationships:
      links: []
    state:
      current_commitments: []
      current_risks: []
      current_visibility:
        known_to_self: []
        known_to_others: []
      last_updated_beat_id: null
  }

mkCostItem = ->
  {
    kind: "unknown"
    description: "unknown"
    observable_marker:
      statement: "unknown"
      evidence_spans: []
    magnitude:
      level: "unknown"
    confidence: 0.0
  }

mkPlotAtom = (storyRef, sourceId, sourceText, para, firstCharRef) ->
  {
    id: hashId('pa', storyRef, para.start, para.stop, para.text)
    type: "action"
    agent_ref: firstCharRef ? "unknown"
    target_ref: "unknown"
    action: para.text.split(/[.!?]/)[0].trim() ? "unknown"
    outcome: "unknown"
    cost:
      items: [mkCostItem()]
      confidence: 0.0
    reveal:
      items: []
      confidence: 0.0
    timestamp:
      story_time: "unknown"
      order_index: para.start
    evidence_spans: [toEvidence(sourceId, sourceText, para.start, Math.min(para.stop, para.start + 160))]
    confidence: 0.35
    fingerprint: "sha256:#{sha256("#{storyRef}|#{para.start}|#{para.stop}|#{para.text}")}"
  }

mkBeat = (storyRef, segId, atom, firstCharRef) ->
  unknownSignal =
    character_ref: firstCharRef ? "unknown"
    statement: "unknown"
    candidates: []
    confidence: 0.0
    evidence_spans: []
  {
    id: hashId('beat', storyRef, atom.id)
    segment_ref: segId
    atoms: [atom.id]
    pov:
      pov_character_ref: firstCharRef ? "unknown"
    force_channel:
      suit_id: "unknown"
      rank: "unknown"
      confidence: 0.0
      evidence_spans: []
    trajectory_ready:
      desire: Object.assign {}, unknownSignal
      fear: Object.assign {}, unknownSignal
      choice:
        character_ref: firstCharRef ? "unknown"
        options: []
        selected_option_id: "unknown"
        confidence: 0.0
        evidence_spans: []
      pressure:
        applied_by_ref: "unknown"
        target_ref: "unknown"
        description: "unknown"
        mode: "unknown"
        confidence: 0.0
        evidence_spans: []
      cost:
        items: [mkCostItem()]
        confidence: 0.0
        evidence_spans: []
      reveal:
        items: []
        confidence: 0.0
        evidence_spans: []
      belief_touched: Object.assign {}, unknownSignal
      mask_engaged: Object.assign {}, unknownSignal
      wound_triggered:
        character_ref: firstCharRef ? "unknown"
        trigger_pattern: "unknown"
        response_pattern: "unknown"
        candidates: []
        confidence: 0.0
        evidence_spans: []
    assembly_links:
      leads_to_beat_ids: []
      depends_on_beat_ids: []
    fingerprint: "sha256:#{sha256("#{storyRef}|#{atom.id}")}"
  }

mkSegment = (storyRef, beatIds, characterRefs) ->
  {
    id: hashId('seg', storyRef, beatIds.join('|'))
    title: "Main Segment"
    situation:
      location: "unknown"
      time: "unknown"
      constraints: []
      objects_in_play: []
    cast_refs: sortStrings(characterRefs)
    beats: sortStrings(beatIds)
    segment_pressure:
      description: "unknown"
      target_ref: "unknown"
      escalation_pattern: "unknown"
    segment_reveals: []
    segment_costs: []
    unresolved_cost:
      description: "unknown"
      confidence: 0.0
    exit_state:
      changed_relationships: []
      changed_commitments: []
      changed_access: []
    fingerprint: "sha256:#{sha256("#{storyRef}|#{beatIds.join('|')}")}"
  }

mkArc = (storyRef, segId) ->
  {
    id: hashId('arc', storyRef, segId)
    arc_type:
      label: "unknown"
    segments: [segId]
    escalation:
      modes: []
      pressure_targets: []
      slope: "unknown"
    resolution:
      terminal_choice_beat_ref: "unknown"
      terminal_costs: []
      open_loops_remaining: []
    arc_reveals: []
    arc_costs: []
    fingerprint: "sha256:#{sha256("#{storyRef}|#{segId}")}"
  }

extractStory = (STORY_CFG) ->
  throw new Error "Each story must be an object" unless STORY_CFG? and typeof STORY_CFG is 'object'
  throw new Error "Each story requires 'text'" unless typeof STORY_CFG.text is 'string' and STORY_CFG.text.length > 0

  SOURCE_ID = String(STORY_CFG.source_id ? STORY_CFG.id ? "story_source")
  STORY_REF = hashId('story', String(STORY_CFG.id ? SOURCE_ID), SOURCE_ID)

  SOURCE_TEXT = STORY_CFG.text
  PARAS = splitParagraphs(SOURCE_TEXT)

  NAMES = if Array.isArray(STORY_CFG.characters) and STORY_CFG.characters.length > 0 then STORY_CFG.characters else inferCharacters(SOURCE_TEXT)
  NAMES = sortStrings(Array.from(new Set(NAMES.map((n) -> String(n).trim()).filter((n) -> n.length > 0))))

  CHARS = sortById(NAMES.map((n) -> mkCharacter(STORY_REF, n)))
  CHAR_REFS = sortStrings(CHARS.map((c) -> c.id))
  FIRST_CHAR_REF = CHAR_REFS[0]

  ATOMS = (mkPlotAtom(STORY_REF, SOURCE_ID, SOURCE_TEXT, para, FIRST_CHAR_REF) for para in PARAS)
  ATOMS.sort (a, b) ->
    diff = a.timestamp.order_index - b.timestamp.order_index
    return diff if diff isnt 0
    a.id.localeCompare(b.id)

  SEG_ID = hashId('seg', STORY_REF, ATOMS.map((a) -> a.id).join('|'))
  BEATS = sortById((mkBeat(STORY_REF, SEG_ID, atom, FIRST_CHAR_REF) for atom in ATOMS))
  SEG = mkSegment(STORY_REF, BEATS.map((b) -> b.id), CHAR_REFS)
  ARC = mkArc(STORY_REF, SEG.id)

  ISSUES = []
  if PARAS.length is 0
    ISSUES.push
      id: hashId('iss', STORY_REF, 'no_paragraphs')
      kind: "missing_field"
      message: "Story contained no non-empty paragraphs"
      affected_ids: [STORY_REF]
      suggested_candidates: []
      confidence: 1.0
  ISSUES = sortById(ISSUES)

  {
    story_ref: STORY_REF
    extracted_characters: CHARS
    extracted_atoms: ATOMS
    extracted_beats: BEATS
    extracted_segments: [SEG]
    extracted_arcs: [ARC]
    issues: ISSUES
  }

extractStories = (STORIES) ->
  ANALYSES = (extractStory(S) for S in STORIES)
  ANALYSES.sort (a, b) -> String(a.story_ref).localeCompare(String(b.story_ref))

runSelftest = (STORIES) ->
  FIRST = extractStories(STORIES)
  SECOND = extractStories(STORIES)
  A = stableStringify(FIRST)
  B = stableStringify(SECOND)
  throw new Error "Selftest failed: extraction output is not stable across runs" unless A is B
  true

validateCfg = (CFG, STEP_NAME) ->
  throw new Error "Missing experiment.yaml in memo" unless CFG?
  throw new Error "Missing config for step '#{STEP_NAME}'" unless CFG[STEP_NAME]?
  throw new Error "Missing '#{STEP_NAME}.schema_ref'" unless typeof CFG[STEP_NAME].schema_ref is 'string' and CFG[STEP_NAME].schema_ref.length > 0
  true

selftestEnabled = (argv = process.argv.slice(2), stepFlag) ->
  return true if stepFlag is true
  argv.some (arg) -> /^--selftest(?:=.+)?$/.test(String(arg))

@step =
  desc: "Extract plot + character structures from a series of stories"

  action: (M, STEP_NAME) ->
    CFG = M.theLowdown('experiment.yaml')?.value
    validateCfg(CFG, STEP_NAME)
    STEP_CFG = CFG[STEP_NAME]
    CHAPTER_TEXT = await M.need(STEP_NAME, 'chapter_text')
    CHARACTERS = await M.need(STEP_NAME, 'characters')
    STORIES = [{
      id: String(STEP_CFG.story_id ? 'story_sample_chapter')
      title: String(STEP_CFG.story_title ? 'Sample Chapter')
      source_id: "artifact:chapter_text"
      text: CHAPTER_TEXT
      characters: CHARACTERS
    }]

    LOGGER = createLogger(STEP_NAME,
      selftest: selftestEnabled(process.argv.slice(2), STEP_CFG.selftest)
      story_count: STORIES.length
      output_artifact: 'analysis'
      schema_ref: STEP_CFG.schema_ref
    )

    try
      if selftestEnabled(process.argv.slice(2), STEP_CFG.selftest)
        runSelftest(STORIES)
        LOGGER.info("selftest=ok stories=#{STORIES.length}")

      ANALYSES = extractStories(STORIES)
      PAYLOAD =
        schema_ref: STEP_CFG.schema_ref
        mode: "analysis"
        source_count: STORIES.length
        analyses: ANALYSES

      M.put STEP_NAME, 'analysis', PAYLOAD
      M.saveThis "done:#{STEP_NAME}", true
      LOGGER.close('ok')
      console.log "Extracted plot/character analysis for #{STORIES.length} stories -> artifact analysis"
      return
    catch ERR
      LOGGER.error(ERR.message ? String(ERR))
      LOGGER.close('error')
      throw ERR

main = ->
  ARGS = process.argv.slice(2)
  unless ARGS.length >= 1 and /^--selftest(?:=.+)?$/.test(String(ARGS[0])) and ARGS.length <= 2
    throw new Error "Standalone usage: coffee guild/extract_plot_character.coffee --selftest [config.json]"

  CFG_PATH = ARGS[1]
  throw new Error "Standalone selftest requires a config.json path" unless CFG_PATH?
  CFG_PATH_ABS = resolveInputPath(CFG_PATH)
  CFG = JSON.parse(fs.readFileSync(CFG_PATH_ABS, 'utf8'))
  throw new Error "Config file must include a non-empty stories array" unless Array.isArray(CFG.stories) and CFG.stories.length > 0
  runSelftest(CFG.stories)
  console.log "selftest OK (#{CFG.stories.length} stories)"

if require.main is module
  try
    main()
  catch ERR
    console.error ERR.message ? String(ERR)
    process.exit(1)
