#!/usr/bin/env bash
#
# run-first.sh — one-command bootstrap for writers-guild.
#
# Run this once after `git clone`. It does, in order:
#
#   1. pnpm install     — pulls @jahbini/pipeline from GitHub
#   2. pnpm run setup   — creates .venv and pip-installs the pipeline
#                          runtime requirements (MLX, etc.) plus this
#                          project's own requirements.txt
#   3. pnpm run pipeline — runs the pipeline named in override.yaml
#
# Note: this repo ships its own override.yaml (pipeline: jim_story),
# so `setup` does NOT overwrite it. If you want the package's test
# override instead, run `pnpm run setup:override` explicitly.
#
# After this finishes, `pnpm run pipeline` re-runs the pipeline,
# `pnpm run ui` launches the local web UI, and `pnpm run clean`
# wipes runtime artifacts.
#
set -euo pipefail
cd "$(dirname "$0")"

banner() {
  echo
  echo "════════════════════════════════════════════════════════════════════"
  echo "  $1"
  echo "════════════════════════════════════════════════════════════════════"
}

banner "1/3  pnpm install — pulling @jahbini/pipeline from GitHub"
pnpm install

banner "2/3  pnpm run setup — .venv with MLX (slow first time)"
pnpm run setup

banner "3/3  pnpm run pipeline — running the configured pipeline"
pnpm run pipeline

echo
echo "Done. Edit override.yaml to switch pipelines, or run \`pnpm run ui\`"
echo "to launch the local web UI on http://127.0.0.1:4311."
