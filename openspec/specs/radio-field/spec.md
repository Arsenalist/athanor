# Radio Field

## Purpose

Defines the built-in `:radio` component field type, its options contract, selected-value matching, write-back behavior through the fields form, and shared label/conditional handling, providing a single-select control rendered as a group of radio inputs with no host-supplied module.

## Requirements

### Requirement: Built-in `:radio` field type

`Athanor.Fields` SHALL render a built-in field of type `:radio` declared in a
component's `fields/0` as `{key, :radio, opts}`, requiring no host-supplied module.
`:radio` MUST be a recognized value of `Athanor.Component.field_type`.

#### Scenario: Component declares a radio field

- **WHEN** a component declares `{"level", :radio, label: "Level", options: [{"H1", "1"}, {"H2", "2"}]}`
- **THEN** `Athanor.Fields` renders a radio control for `"level"` without any
  `module:` reference
- **AND** one `<input type="radio">` is rendered per option, all sharing
  `name="level"`

#### Scenario: `:radio` is an accepted field type

- **WHEN** the `Athanor.Component.field_type` typespec is inspected
- **THEN** `:radio` is included alongside `:text`, `:textarea`, `:number`,
  `:select`, `:color`, `:checkbox`, `:asset`, and `:custom`

### Requirement: Radio options contract

A `:radio` field SHALL accept its choices via an `options:` opt using the same
contract as `:select`: either a static `[{label, value}, …]` keyword/tuple list, or
an arity-1 function receiving the `Ctx` that returns such a list. The function form
SHALL be resolved lazily at render time.

#### Scenario: Static options list

- **WHEN** a radio field declares `options: [{"Left", "left"}, {"Right", "right"}]`
- **THEN** two radio inputs render with values `"left"` and `"right"` and labels
  `"Left"` and `"Right"` respectively

#### Scenario: Options as a function of Ctx

- **WHEN** a radio field declares `options: fn _ctx -> [{"A", "a"}, {"B", "b"}] end`
- **THEN** the function is invoked at render time
- **AND** the radio inputs reflect the returned `[{label, value}, …]` list

#### Scenario: Missing or invalid options

- **WHEN** a radio field has no `options:` (or a non-list, non-function value)
- **THEN** the field renders with zero radio inputs and does not raise

### Requirement: Selected value matching

A `:radio` field SHALL mark exactly the input whose `value` matches the current prop
as `checked`, using the same string-normalized comparison as `:select`
(`to_string(props[key]) == to_string(value)`). When no option matches, no input is
checked.

#### Scenario: Current value selects its option

- **WHEN** the prop `"level"` is `"2"` and options are `[{"H1", "1"}, {"H2", "2"}]`
- **THEN** the input with `value="2"` is `checked`
- **AND** the input with `value="1"` is not `checked`

#### Scenario: Value compared across types

- **WHEN** the prop value is the integer `2` and an option `value` is the string `"2"`
- **THEN** that option's input is `checked` (string-normalized comparison)

#### Scenario: No matching value

- **WHEN** the prop is `nil` or matches no option `value`
- **THEN** no radio input is `checked`

### Requirement: Radio write-back through the fields form

A `:radio` field SHALL post its selected value through the existing fields
`<form phx-change=...>` like other built-in fields, with all of the group's inputs
sharing the field `name`, so selecting an option submits that option's `value` as the
form param for the field key. `:radio` SHALL introduce no field-specific event.

#### Scenario: Selecting an option submits its value

- **WHEN** a user selects the radio input with `value="right"` in a `"align"` field
- **THEN** the fields form's `phx-change` submits `align => "right"` as a form param
- **AND** no event other than the form's existing change event is emitted

### Requirement: Radio honors label and conditional `if:`

A `:radio` field SHALL render its `label:` opt when present and SHALL honor the
shared conditional `if: fn props -> boolean end` opt, being omitted from the
rendered fields when the function returns false against the current props.

#### Scenario: Label rendered

- **WHEN** a radio field declares `label: "Alignment"`
- **THEN** the rendered group includes the text `"Alignment"`

#### Scenario: Conditional field omitted

- **WHEN** a radio field declares `if: fn props -> props["enabled"] == true end`
  and the current props have `"enabled"` falsey
- **THEN** the radio field is omitted from the rendered fields
