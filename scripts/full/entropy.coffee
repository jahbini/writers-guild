#!/usr/bin/env coffee
###
entropy.coffee — memo-native
----------------------------
Reads prompts + policy + artifacts from memo/meta.
Writes token entropy rows and summary rows via memo keys.
###

@step =
  desc: "Compute per-token entropy from MLX stream_generate (memo-native)"

  action: (M, stepName) ->
    params = (M.theLowdown "params/#{stepName}.json").value

    GEN_JSONL   = params.generations + ".jsonl"
    TOK_PATH    = params.entropy_tokens + ".jsonl"
    SUM_PATH    = params.entropy_summary + ".csv"
    POLICY_FILE = params.policy

    MAX_NEW   = parseInt(params.max_new_tokens)
    STOP_STRS = params.stop_strings
    unless Array.isArray(STOP_STRS) and STOP_STRS.length
      throw new Error "stop_strings must be non-empty array"

    logs = []
    log = (msg) ->
      t = new Date().toISOString().replace('T',' ').replace(/\.\d+Z$/,'')
      line = "[#{t}] #{msg}"
      logs.push line
      console.log line

    loadPolicy = ->
      p = M.theLowdown(POLICY_FILE)
      p.value ? await p.notifier

    loadPrompts = ->
      p = M.theLowdown(GEN_JSONL)
      p.value ? await p.notifier

    regKey = M.getStepParam(stepName, "artifacts")
    regEntry = M.theLowdown(regKey)
    registry = regEntry.value ? await regEntry.notifier
    throw new Error "Missing artifacts in memo" unless registry?

    runs = registry.runs or []
    throw new Error "No runs found in artifacts registry" unless runs.length

    pickArtifact = (policy) ->
      pref = policy?.artifact_preference or ['quantized','fused','adapter']
      cands = []
      for re in runs by -1
        if re.quantized_dir? then cands.push ['quantized', re.quantized_dir, null]
        if re.fused_dir?     then cands.push ['fused', re.fused_dir, null]
        if re.adapter_dir?   then cands.push ['adapter', re.model_id, re.adapter_dir]
      for want in pref
        for [lab, mpath, apath] in cands when lab is want
          return [mpath, apath, lab]
      cands[0]

    entropyFromLogprobs = (logs) ->
      maxv = Math.max.apply(null, logs)
      exps = logs.map((v) -> Math.exp(v - maxv))
      Z = exps.reduce(((a, b) -> a + b), 0)
      ps = exps.map((e) -> e / (Z + 1e-12))
      -ps.reduce(((a, p) -> a + p * Math.log(p + 1e-12)), 0)

    median = (xs) ->
      return 0 unless xs.length
      ys = xs.slice().sort((a, b) -> a - b)
      n = ys.length
      if n % 2 then ys[(n - 1) / 2] else 0.5 * (ys[n / 2 - 1] + ys[n / 2])

    applyPromptPolicy = (p, policy) ->
      pp = policy?.prompt_policy or {name: 'plain'}
      switch pp.name
        when 'directive'
          "#{p}#{pp.directive?.suffix or ''}"
        when 'fewshot'
          fspec = pp.fewshot or {}
          prefix = fspec.prefix or ''
          joiner = fspec.joiner or '\n'
          suffix = fspec.suffix or '\n'
          shots = fspec.shots or []
          "#{prefix}#{shots.join(joiner)}#{suffix}".replace('{prompt}', p)
        else
          p

    policy = loadPolicy()
    prompts = loadPrompts()
    [modelPath, adapterPath, artifactLabel] = pickArtifact(policy)

    log "Model: #{modelPath}"
    log "Adapter: #{adapterPath or '(none)'}"

    tokenRows = []
    summaryRows = []
    idx = 0

    for rawPrompt in prompts or []
      promptText = if typeof rawPrompt is 'string' then rawPrompt else rawPrompt?.prompt ? rawPrompt?.text ? String(rawPrompt ? '')
      fullPrompt = applyPromptPolicy(promptText, policy)

      args =
        model: modelPath
        prompt: fullPrompt
        "max-tokens": MAX_NEW
        stop: STOP_STRS
      args["adapter-path"] = adapterPath if adapterPath?

      log "stream_generate for prompt #{idx}"
      out = await M.callMLX("stream_generate", args)
      if out?.error?
        log "ERROR: #{out.error}"
        idx++
        continue

      ent = []
      for r in (out.records or [])
        continue unless r.logprobs?
        H = entropyFromLogprobs(r.logprobs)
        ent.push H
        tokenRows.push
          artifact: artifactLabel
          prompt_idx: idx
          token: r.token
          entropy: H

      if ent.length
        meanH = ent.reduce(((a, b) -> a + b), 0) / ent.length
        medH = median(ent)
        minH = Math.min.apply(null, ent)
        maxH = Math.max.apply(null, ent)
        summaryRows.push
          artifact: artifactLabel
          prompt_idx: idx
          tokens: ent.length
          mean_entropy: Number(meanH.toFixed(4))
          median_entropy: Number(medH.toFixed(4))
          min_entropy: Number(minH.toFixed(4))
          max_entropy: Number(maxH.toFixed(4))
      idx++

    M.saveThis TOK_PATH, tokenRows
    M.saveThis SUM_PATH, summaryRows
    M.saveThis "#{stepName}.log", logs.join("\n") + "\n"
    M.saveThis "#{stepName}:paths", {tokens: TOK_PATH, summary: SUM_PATH}
    return
