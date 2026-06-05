# Asset Field

## Purpose

Defines the built-in `:asset` component field type, its descriptor value contract, cardinality, request signaling, and write-back behavior, keeping Athanor upload-agnostic while supporting host-provided asset pickers.

## Requirements

### Requirement: Built-in `:asset` field type

`Athanor.Fields` SHALL render a built-in field of type `:asset` declared in a
component's `fields/0` as `{key, :asset, opts}`, requiring no host-supplied module.
`:asset` MUST be a recognized value of `Athanor.Component.field_type`.

#### Scenario: Component declares an asset field with no host module

- **WHEN** a component declares `{"hero", :asset, accept: "image/*"}`
- **THEN** `Athanor.Fields` renders an asset field for `"hero"` without any
  `module:` reference
- **AND** the rendered markup carries a stable testid identifying it as an asset field

#### Scenario: `:asset` is an accepted field type

- **WHEN** the `Athanor.Component.field_type` typespec is inspected
- **THEN** `:asset` is included alongside `:text`, `:textarea`, `:number`, `:select`,
  `:color`, `:checkbox`, and `:custom`

### Requirement: Asset descriptor value contract

An asset value SHALL be a plain, string-keyed, JSON-serializable map (an "asset
descriptor"). Athanor SHALL read only `"url"`, `"name"`, and `"content_type"` and
SHALL preserve all other keys untouched.

#### Scenario: Descriptor extras are preserved

- **WHEN** a descriptor `%{"url" => "u", "name" => "n", "content_type" => "image/png", "alt" => "a", "width" => 800}` is set as the field value
- **THEN** Athanor renders chrome using `url`/`name`/`content_type` only
- **AND** the `"alt"` and `"width"` keys remain in the value unchanged for the
  component to consume

#### Scenario: Image descriptor renders a thumbnail

- **WHEN** the descriptor `"content_type"` begins with `"image/"`
- **THEN** the field preview renders a thumbnail using the descriptor `"url"`

#### Scenario: Non-image descriptor renders a filename chip

- **WHEN** the descriptor `"content_type"` does not begin with `"image/"`
  (e.g. `"application/pdf"`)
- **THEN** the field preview renders the descriptor `"name"` with a generic
  (non-thumbnail) indicator

#### Scenario: Missing content_type falls back to URL sniffing

- **WHEN** a descriptor has no `"content_type"` but its `"url"` ends in an image
  extension
- **THEN** the field still renders a thumbnail and does not error

### Requirement: Cardinality (single vs multiple)

An `:asset` field SHALL default to single-value. When declared with `multiple: true`
it SHALL hold a list of descriptors. `min`/`max` opts SHALL be forwarded to the host
but SHALL NOT be enforced by Athanor.

#### Scenario: Single asset value shape

- **WHEN** an `:asset` field without `multiple` has a value
- **THEN** the value is a single descriptor map (or `nil` when unset)
- **AND** the field renders a single preview slot plus a choose control

#### Scenario: Multiple asset value shape

- **WHEN** an `:asset` field declared `multiple: true` has a value
- **THEN** the value is a list of descriptor maps (or `[]` when unset)
- **AND** the field renders one chip per descriptor (labelled by `"name"`) plus an
  add control and a per-item remove control

### Requirement: Asset request signal

Clicking the field's choose/add control SHALL emit a fixed `"athanor_asset_request"`
event carrying at least the field `key`, with no `phx-target` so it routes to the
editor LiveView. Athanor SHALL NOT itself perform any upload, storage, or browse
action in response.

#### Scenario: Choosing emits the request event

- **WHEN** the user activates the field's choose (or add) control
- **THEN** an `"athanor_asset_request"` event is emitted that includes the field `key`
- **AND** Athanor performs no upload or storage work itself

### Requirement: Bare-minimal default without a host picker

With no host asset-request handling wired, an `:asset` field SHALL remain functional
by allowing a URL to be entered directly, producing a descriptor with that `"url"`.

#### Scenario: URL paste produces a descriptor

- **WHEN** no host picker is wired and the user enters a URL into the field's URL input
- **THEN** the field value becomes a descriptor whose `"url"` is the entered string

### Requirement: Write-back via existing props channel

A new asset value SHALL be applied to the node by the existing
`{:update_component_props, node_id, props}` mechanism (wholesale replace of the field
key). The `:asset` field SHALL re-render its preview from the updated value.

#### Scenario: Updated value re-renders the preview

- **WHEN** the field's value is replaced via `update_component_props` with a new
  descriptor
- **THEN** the field preview reflects the new descriptor without any field-local state

### Requirement: Conditional visibility parity

An `:asset` field SHALL honor the existing `if:` field option, omitting the field when
the predicate returns false against current props.

#### Scenario: Hidden when predicate is false

- **WHEN** an `:asset` field declares `if: fn props -> props["enabled"] == true end`
  and `props["enabled"]` is not true
- **THEN** the field is not rendered
