## Why

Single-choice selection today is only expressible as a `:select` dropdown. For
short, mutually-exclusive option sets (2–5 choices), a dropdown hides the options
behind a click and reads poorly in a config panel; a radio-button group surfaces
every choice inline. Athanor needs a built-in `:radio` field so component authors
get an ergonomic single-choice control without falling back to a `:custom` field.

## What Changes

- Add a built-in `:radio` field type to `Athanor.Fields`. Components declare
  `{"level", :radio, label: "Level", options: [{"H1", "1"}, {"H2", "2"}]}` — same
  `options:` contract as `:select` (static `[{label, value}, …]` list **or** an
  arity-1 function of `Ctx` resolved lazily at render).
- Render the group as `<input type="radio">` controls sharing the field's `name`
  so a single `phx-change` submits the selected value, matching how `:select`,
  `:checkbox`, and the other built-ins post into the fields form.
- Mark the current value selected via the same string-normalized comparison
  `:select` uses (`to_string(props[key]) == to_string(value)`), so saved props are
  back-compatible with switching a field from `:select` to `:radio`.
- Add `:radio` to the `field_type` typespec and the built-in-types documentation in
  `Athanor.Component` and the `Athanor.Fields` moduledoc.

No breaking changes. `:select` and every other built-in keep working unchanged.
Switching a field from `:select` to `:radio` requires no data migration — both read
and write the same scalar prop value.

## Capabilities

### New Capabilities

- `radio-field`: the built-in `:radio` field type — declaration options
  (`options:`/`label:`/`if:`), the static-or-function `options:` contract shared with
  `:select`, the rendered radio-group chrome and `name`-grouping, the
  selected-value comparison rule, and write-back through the existing fields form.

### Modified Capabilities

<!-- none — :radio is additive; no existing captured capability's requirements change -->

## Impact

- **Athanor (this repo)**: `lib/athanor/fields.ex` (new `:radio` field clause reusing
  `resolve_options/2`; moduledoc built-in-types list), `lib/athanor/component.ex`
  (`field_type` typespec adds `:radio`; built-in-types doc line). Tests in
  `test/athanor/fields_test.exs` (render + selection + function-options + `if:`).
- **Dependencies**: none added.
- **Hosts**: opt-in. Existing components are untouched; authors may switch suitable
  `:select` fields to `:radio` incrementally with no data migration.
