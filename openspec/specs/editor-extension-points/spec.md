# Editor Extension Points

## Purpose

Defines the editor host extension contract for asset requests — the `AssetRequest` struct, the `handle_asset_request/2` callback, the pending request lifecycle, the general `render_outlet/1` render callback — while keeping Athanor upload-agnostic.

## Requirements

### Requirement: AssetRequest struct

Athanor SHALL provide `%Athanor.Editor.AssetRequest{}` describing a request for an
asset, with `node_id` and `key` enforced and `accept`, `multiple`, `min`, `max`,
`current` optional. The struct exists so the host callback contract can evolve
without changing arity.

#### Scenario: Struct requires node_id and key

- **WHEN** an `AssetRequest` is built without `node_id` or `key`
- **THEN** construction raises (enforced keys)

#### Scenario: Struct carries field declaration and current value

- **WHEN** an `:asset` field declared `multiple: true, accept: "image/*", max: 12`
  with a current value emits a request
- **THEN** the resulting `AssetRequest` carries `accept`, `multiple`, `max`, and the
  `current` value for the host to interpret

### Requirement: `handle_asset_request/2` host callback

`Athanor.Editor` SHALL define an optional `handle_asset_request(socket, request)`
callback. The turn-key editor SHALL route the `"athanor_asset_request"` event into
this callback when the consumer module exports it, and SHALL no-op safely otherwise.
Athanor SHALL pass the request as an `%Athanor.Editor.AssetRequest{}`.

#### Scenario: Event routed to host implementation

- **WHEN** the editor receives `"athanor_asset_request"` and the consumer module
  exports `handle_asset_request/2`
- **THEN** Athanor invokes `handle_asset_request(socket, %AssetRequest{})` with the
  request derived from the event params and node/field context

#### Scenario: No-op when host does not implement the callback

- **WHEN** the editor receives `"athanor_asset_request"` and the consumer module does
  not implement `handle_asset_request/2`
- **THEN** the event is handled without error and no upload/storage work occurs

### Requirement: Pending asset-request lifecycle

The editor SHALL track a single pending asset request in its state
(`asset_request`, an `%Athanor.Editor.AssetRequest{}` or `nil`) so a host picker
rendered via `render_outlet/1` can be shown while a request is pending and dismissed
when it resolves — without the host needing its own `handle_info`. The pending
request SHALL be set on `"athanor_asset_request"` and cleared per the rules below.
It SHALL NOT be persisted (never written into content/metadata or the save payload).

#### Scenario: Request sets the pending state

- **WHEN** the editor receives `"athanor_asset_request"` for node `"n1"`, key `"hero"`
- **THEN** `asset_request` is a `%AssetRequest{node_id: "n1", key: "hero"}`

#### Scenario: Explicit cancel clears it

- **WHEN** the editor receives `"athanor_asset_cancel"` while a request is pending
- **THEN** `asset_request` becomes `nil`

#### Scenario: Write-back to the pending key clears it

- **WHEN** a request is pending for node `"n1"`/`"hero"` with current value `nil`
- **AND** `{:update_component_props, "n1", %{"hero" => %{"url" => "u"}}}` arrives
- **THEN** the prop is written AND `asset_request` becomes `nil`

#### Scenario: Unrelated edit on the same node does NOT clear it

- **WHEN** a request is pending for node `"n1"`/`"hero"` with current value `nil`
- **AND** `{:update_component_props, "n1", %{"hero" => nil, "title" => "new"}}` arrives
  (the pending key's value is unchanged)
- **THEN** `asset_request` remains set (the picker stays open)

#### Scenario: Navigation clears it

- **WHEN** a request is pending and the editor handles `select_component`,
  `close_config`, or `remove_component`
- **THEN** `asset_request` becomes `nil`

### Requirement: General `render_outlet/1` render callback

`Athanor.Editor` SHALL define an optional `render_outlet/1` render callback that
defaults to empty output and is overridable by consumers. The turn-key editor SHALL
render its output into the shell's existing `:modals` slot, alongside the library's
own modal. The callback is form-agnostic — it is a general host render region, not a
modal-specific hook.

#### Scenario: Default outlet renders nothing

- **WHEN** a consumer does not override `render_outlet/1`
- **THEN** the editor renders normally and the outlet contributes no visible markup

#### Scenario: Host outlet markup appears in the editor

- **WHEN** a consumer overrides `render_outlet/1` to return markup
- **THEN** that markup is rendered into the editor's modal layer alongside the
  library's own modal

#### Scenario: Outlet callback is overridable

- **WHEN** the generated turn-key editor module's overridable callbacks are inspected
- **THEN** `render_outlet/1` is overridable alongside `render_header/1`,
  `render_top_bar_actions/1`, and `seed_default_props/3`

### Requirement: Athanor remains upload-agnostic

Athanor source SHALL NOT reference any upload mechanism or media-specific concept.
This is verified by the architecture test.

#### Scenario: No forbidden upload tokens in Athanor source

- **WHEN** the architecture test scans `lib/` source
- **THEN** it finds no references to `MediaUploader`, `allow_upload`, or
  `consume_uploaded_entries`, and no media-kind-specific field handling leaks the
  notion of "upload" into the library
