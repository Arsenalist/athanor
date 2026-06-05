## 1. Register the `:radio` field type

- [x] 1.1 Add `:radio` to the `@type field_type` union in `lib/athanor/component.ex`
- [x] 1.2 Add `:radio` to the built-in-types list in the `Athanor.Component` moduledoc
- [x] 1.3 Add `:radio` to the built-in-types list in the `Athanor.Fields` moduledoc

## 2. Render the radio field

- [x] 2.1 Add `defp field(%{type: :radio} = assigns)` in `lib/athanor/fields.ex`,
  adjacent to the `:select` clause, resolving options via `resolve_options(assigns.opts[:options], assigns)`
- [x] 2.2 Render `label:` (when present) plus one `<label><input type="radio" name={@key} value={value} checked={…}/> label</label>` per option
- [x] 2.3 Set `checked` with the `:select` comparison `to_string(@props[@key]) == to_string(value)`
- [x] 2.4 Confirm zero options renders no inputs and does not raise (reuses `resolve_options/2` fallbacks)

## 3. Tests

- [x] 3.1 In `test/athanor/fields_test.exs`, test a static-options radio renders one input per option sharing `name`
- [x] 3.2 Test the current prop value marks the matching option `checked`, including cross-type (integer prop vs string option value) and no-match (nothing checked)
- [x] 3.3 Test `options:` as an arity-1 function of Ctx resolves at render
- [x] 3.4 Test `label:` renders and `if: fn props -> false end` omits the field
- [x] 3.5 Test selecting an option posts `key => value` through the fields form `phx-change`

## 4. Verify

- [x] 4.1 Run `mix test` and confirm the radio-field specs are satisfied
- [x] 4.2 Run `openspec validate add-radio-field --strict`
