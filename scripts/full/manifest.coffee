#!/usr/bin/env coffee
###
manifest.coffee — memo-native
-----------------------------
Captures environment info and dependency lock text.
All outputs are written through memo keys.
###

path    = require 'path'
crypto  = require 'crypto'
child   = require 'child_process'
os      = require 'os'

@step =
  desc: "Capture environment info and create manifest (memo-native)"

  action: (M, stepName) ->
    params = (M.theLowdown "params/#{stepName}.json").value
    LOCK_KEY      = params.requirements_lock
    MANIFEST_YAML = params.manifest + ".yaml"
    MANIFEST_JSON = params.manifest + ".json"
    SEED          = params.seed

    runCmd = (cmd) ->
      try
        res = child.spawnSync(cmd, {shell: true, encoding: 'utf8'})
        [res.status ? 1, (res.stdout ? '').trim(), (res.stderr ? '').trim()]
      catch e
        [1, '', String(e)]

    which = (bin) ->
      [code, out] = runCmd("which #{bin}")
      if code is 0 and out.length then out else null

    pipVersion = (pkg) ->
      py = which('python3') ? which('python')
      return null unless py?
      [code, out] = runCmd("#{py} -m pip show #{pkg}")
      return null unless code is 0
      for line in out.split(/\r?\n/)
        if line.startsWith('Version:')
          return line.split(':')[1].trim()
      null

    [freezeCode, freezeOut, freezeErr] = runCmd("#{which('python3') ? 'python3'} -m pip freeze")
    lockText = null
    lockHash = null
    if freezeCode is 0
      lockText = freezeOut + "\n"
      lockHash = crypto.createHash('sha256').update(lockText).digest('hex')

    platformInfo =
      system: os.platform()
      release: os.release()
      version: (os.version?() or 'unknown')
      machine: os.arch()
      processor: os.cpus()[0]?.model or 'unknown'

    if platformInfo.system.toLowerCase().includes('darwin')
      [code, out] = runCmd('sysctl -n machdep.cpu.brand_string')
      platformInfo.chip_brand = if code is 0 then out else null

    pkgs =
      'mlx-lm': pipVersion('mlx-lm')
      'datasets': pipVersion('datasets')
      'pandas': pipVersion('pandas')
      'tqdm': pipVersion('tqdm')
      'numpy': pipVersion('numpy')

    manifest =
      timestamp_utc: new Date().toISOString().replace(/\.\d+Z$/, 'Z')
      seed: SEED
      platform: platformInfo
      packages: pkgs
      executables:
        node: process.execPath
        python_which: which('python')
        pip_which: which('pip')
      artifacts:
        requirements_lock: LOCK_KEY
        requirements_lock_sha256: lockHash
      notes: [
        "Manifest and lock are memo-backed for storage portability."
      ]
      warnings: if freezeCode is 0 then [] else ["pip freeze failed: #{freezeErr}"]

    M.saveThis LOCK_KEY, lockText if lockText?
    M.saveThis MANIFEST_YAML, manifest
    M.saveThis MANIFEST_JSON, manifest
    M.saveThis "#{stepName}.log", "manifest saved: #{MANIFEST_YAML}\n"
    return
