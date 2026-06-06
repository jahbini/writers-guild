#!/usr/bin/env bash
#
# test.sh — smoke tests for writers-guild pipeline steps.
#
# Runs deterministic steps (no MLX required) via standalone harnesses,
# writes artifacts and assertion reports into test/.
#
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p test

run_one() {
  local label="$1" ; shift
  echo
  echo "════════════════════════════════════════════════════════════════════"
  echo "  $label"
  echo "════════════════════════════════════════════════════════════════════"
  "$@"
}

# 1) assemble_ingredients — primary deterministic step
run_one "assemble_ingredients (story_id=jim_0001)" \
  npx coffee test/run_assemble_ingredients.coffee jim_0001

# 2) determinism check — run twice, diff the bundles
run_one "assemble_ingredients determinism check" bash -c '
  npx coffee test/run_assemble_ingredients.coffee jim_0001 > /dev/null
  cp test/ingredient_bundle.json test/ingredient_bundle.first.json
  npx coffee test/run_assemble_ingredients.coffee jim_0001 > /dev/null
  cp test/ingredient_bundle.json test/ingredient_bundle.second.json
  if diff -q test/ingredient_bundle.first.json test/ingredient_bundle.second.json > /dev/null; then
    echo "[OK  ] same story_id produces identical bundle"
    rm test/ingredient_bundle.first.json test/ingredient_bundle.second.json
  else
    echo "[FAIL] determinism violated — bundles differ across runs"
    diff test/ingredient_bundle.first.json test/ingredient_bundle.second.json | head -40
    exit 1
  fi
'

echo
echo "All smoke tests passed."
