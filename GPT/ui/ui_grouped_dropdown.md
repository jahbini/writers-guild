Area: `UI_grouped_dropdown` directive

Purpose:
- single-select picker for the 5 per-beat fields, rendered as a
  one-at-a-time accordion (group headers expand/collapse, only one
  group open within a picker)
- replaces the native `UI_dropdown` for any field whose source path
  resolves to a dict-of-lists or bare-list shape

Directive syntax (in recipe YAML):
```yaml
scene: [ UI_grouped_dropdown, data/jim_story_library.yaml/library/scenes ]
```

Server side (`ui_server.coffee`):
- new directive handler emits `field.type = 'grouped_dropdown'` with
  `field.groups = [{ label, options: [{ key, label }, ...] }, ...]`
- `loadGroupedDropdownOptions(specPath)` handles three input shapes:
  1. bare list `[...]` → one group with `label: ''`
  2. dict-of-lists `{harbor: [...], cafe: [...]}` → one group per key
  3. legacy dict-of-leaves `{key: {text, ...}}` → one group with `label: ''`
- the `slug` helper that generates option keys MUST stay in sync with
  `scripts/jim/load_library.coffee`'s `slug` — drift breaks the UI's
  round-trip with the runtime
- for the characters shelf the option label is reconstructed as
  `<Name> <gesture>` to match what the model will see as the seed text

Client side (`ui/index.html`):
- renders as `<details>` per group with a `<summary>` header
- each leaf is a radio button; one radio name per picker
- the group containing the current selection auto-opens on render
- accordion behavior: in each `.ui-grouped-picker`, opening one
  `<details>` auto-closes the siblings via a capture-phase `toggle`
  listener (toggle events don't bubble)
- bare-list groups render flat (no `<details>` wrapper) — there's no
  meaningful header to collapse
- `(default)` is a top-level radio above the groups — selects the
  recipe_defaults value at runtime

Persistence:
- the picker's `<div class="ui-grouped-picker" data-path="...">` wrapper
  is the addressable element
- `collectUiValues` reads `wrapper.querySelector('input[type=radio]:checked').value`
- `saveSingleUiField` handles `.ui-grouped-picker` symmetrically with
  `.ui-checkbox` and `.ui-dropdown`
- the document `change` listener catches radio events inside a picker
  and saves the wrapper

Invariants:
- single-select per beat (one radio checked)
- empty selection (default radio) maps to empty string in
  `state/ui-control.json` → triggers recipe_defaults fallback in
  `select_story_recipe`
- non-empty selection is always a canonical flat key matching the
  slug load_library generates

Known pitfalls:
- if a picker shows only one group with no header, the shelf is
  unbucketed (bare list). Sub-bucket the data to get the accordion
  experience back — disturbances was a one-bucket eyesore until we
  re-bucketed into mind_worm / fear / rumor / outrage / etc.
- if a picker shows top-level options that look like locations
  ("harbor", "cafe", ...) instead of seeds, the data was edited but
  ui_server.coffee wasn't restarted. Run `pnpm run ui` again — the
  page does not hot-reload its source.
- writediary uses the same directive name but its own ui_server.coffee
  copy may lag. They're independently maintained (per the
  no-changes-to-writediary directive); convergence is opt-in.
