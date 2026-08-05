# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version is in the `0.x` range, any release MAY contain breaking
changes; the minor version is bumped for each one. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full policy.

## [Unreleased]

## [0.1.0-beta.10] - 2026-08-04

### Changed (BREAKING)

- **Registries are named.** `config :athanor, :components` and
  `config :athanor, :fallback_resolver` are removed — no shim. Configure
  registries instead:

  ```elixir
  config :athanor, :registries,
    page_builder: [
      components: [MyApp.Components.Hero],
      fallback_resolver: {MyApp.LegacyResolver, :resolve_type}
    ],
    channel_overlays: [components: [MyApp.Overlays.Text]]
  ```

  A host app almost always grows a second palette, and one global registry
  makes them leak into each other's pickers and resolve each other's types.
  Setting either removed key now raises with migration instructions rather
  than silently rendering an empty palette.

  Migration:

  - `Athanor.Registry.lookup/1`, `all/0`, `components_metadata/0` and
    `metadata_for/1` take the registry name as their first argument.
  - `Athanor.Ctx` gains `registry`; `Athanor.Renderer` reads it, so every
    ctx used to render a tree must name one.
  - `use Athanor.Editor.Live` requires a `registry:` option (compile-time
    error without it). It becomes the ctx's registry and scopes the
    palette, the config panel and the zone picker.
  - `Athanor.Editor.zone_picker_modal/1` takes a required `registry` attr.
  - `Athanor.Editor.Live.warn_if_registered/2` takes the registry to check
    against; a page-settings module registered in some *other* registry is
    no longer warned about.

### Added

- `Athanor.Registry.registries/0` — names of every configured registry.
- `AthanorDropZone` is reusable outside the editor canvas:
  `data-athanor-drop-event` sets the pushed LiveView event name
  (default `athanor:dnd_drop`), `data-athanor-drop-axis="x"` computes the
  insertion index and draws the indicator horizontally for a row of slots,
  and `data-athanor-drop-index="false"` skips index computation entirely
  for single-slot zones. The drag payload is passed through verbatim, so a
  host can carry its own fields without patching the hook.

## [0.1.0-beta.9] - 2026-07-15

### Added

- `fields/0` field opt `required: true` — renders a required-marker
  asterisk on the field label (text / textarea / number / select / radio
  / asset). Static or driven per-props via `resolve_fields/2`.
- `:radio` field opt `default:` — seeds the checked option when the stored
  value is blank (`nil` / `""`), so configs saved before a radio field
  existed still reflect its default instead of rendering with no option
  selected.

## [0.1.0-beta.8] - 2026-07-15

### Fixed

- `Athanor.Editor.Live.__using__` no longer calls `use Phoenix.Component`
  explicitly — `Phoenix.LiveView`'s own `__using__` already runs it
  internally, so the extra call re-registered `Phoenix.Component`'s
  `@before_compile` hook, producing two identical
  `__phoenix_component_verify__/1` clauses (flagged as redundant by
  Elixir 1.20's type checker) on any consumer that calls tracked function
  components — e.g. Amplify's `PageBuilderLive`.

## [0.1.0-beta.7] - 2026-06-23

### Fixed

- `Columns` width-distribution classes now ship as full literal `md:w-1/2`,
  `md:w-2/3`, `md:w-1/3`, `md:w-3/4`, `md:w-1/4` strings inside
  `@width_distributions`, with `zone_wrapper_class/2` no longer prefixing
  `md:` via interpolation. The previous `md:#{width}` interpolation defeated
  the Tailwind v4 source scanner, so consumers only got CSS for any
  distribution whose responsive class happened to appear literally elsewhere
  in their own source (typically just `md:w-1/2`). Switching a 2-column
  Columns to 66/33, 33/66, 25/75, or 75/25 — or any 3- or 4-column non-equal
  layout — silently shipped without width CSS and collapsed at render time.
  Self-contained fix: consumer's existing `@source ".../deps/athanor/lib/**/*.*ex"`
  glob now picks up every responsive width class as a literal string.

## [0.1.0-beta.6] - 2026-06-16

### Changed

- `Columns` zone wrapper now declares a `@container` query context (both
  storefront and editor-canvas variants). Consumer components that use
  Tailwind container-query utilities (`@sm:*`, `@lg:*`, etc.) inside a
  Columns zone are now sized against the column's width rather than the
  nearest outer `@container` ancestor (typically `<body>`). Non-breaking:
  components rendered outside Columns are unaffected; components that
  don't use container queries are unaffected.

## [0.1.0-beta.5] - 2026-06-14

### Added

- Drag-and-drop insertion-line indicator inside `AthanorDropZone`. On
  `dragover` the zone gets a dashed primary outline + tinted background,
  and a horizontal primary line (with dot endcaps) is positioned at the
  cursor's computed insertion point between sibling drop-items. Empty
  zones show only the outline/tint. Hook self-injects the required
  styles into `document.head` so consumers need no additional CSS.

## [0.1.0-beta.3] - 2026-06-05

### Added

- Built-in `:asset` field type — a host-agnostic picker for uploaded
  assets (image / pdf / video / anything). Ships a paste-a-URL default
  and emits a fixed `"athanor_asset_request"` event the host fulfils;
  Athanor never performs or names an upload. Field opts: `accept:`
  (opaque hint, forwarded), `multiple:` (gallery / multi-file),
  `min:` / `max:` (forwarded, host-enforced). Value is an asset
  descriptor map `%{"url" => ..., "name" => ..., "content_type" => ...}`
  (single) or a list of them (`multiple: true`); opaque extra keys are
  preserved. Single-value paste-URL participates in the existing
  `update_props` form; gallery items get add / remove chrome and an
  `athanor_asset_remove` handler.
- `Athanor.Editor.AssetRequest` struct describing a pending request
  (`node_id`, `key`, `accept`, `multiple`, `min`, `max`, `current`).
- `c:Athanor.Editor.handle_asset_request/2` — optional host callback,
  invoked when an `:asset` field is activated. Default is a no-op (the
  field degrades to paste-a-URL).
- `c:Athanor.Editor.render_outlet/1` — optional, general consumer render
  outlet fed into the shell's `:modals` layer. Host mounts arbitrary
  fixed/offscreen chrome (asset picker, drawer, toast) here. Overridable
  alongside `render_header/1` and `render_top_bar_actions/1`.
- Editor pending-request lifecycle: `Athanor.Editor.State.asset_request`
  tracks the open picker; cleared on the matching write-back (only when
  the pending key's value changes), on `"athanor_asset_cancel"` (event
  or `:athanor_asset_cancel` message), and on
  select / close-config / remove navigation.

## [0.1.0-beta.2] - 2026-06-03

### Added

- Drag-and-drop in the page-builder editor. Drag from the components
  palette onto the canvas, reorder canvas items, drag children in and
  out of `Columns` zones. Server side: new `Athanor.Tree.move_to/4`
  helper and `athanor:dnd_drop` event handled by `Athanor.Editor.Live`.
  Client side: `AthanorHooks` exported from `assets/js/athanor.js`
  with two hooks (`AthanorDragSource`, `AthanorDropZone`) — wire into
  your `LiveSocket` `hooks:`. Native HTML5 DnD, no JS deps.
- `package.json` + `assets/js/` shipped in the Hex tarball so consumers
  can `import "athanor"` directly through esbuild module resolution.

## [0.1.0-beta.1] - 2026-06-02

First public beta. API may shift before `0.1.0` based on early
feedback. Pin tightly (`{:athanor, "== 0.1.0-beta.1"}`) if integrating
during the beta window.

### Added

- `Athanor.Tree` — pure-data manipulation of the editor content tree
  (insert, remove, move, find, with `String.t()`-keyed node ids and
  child-zone slots).
- `Athanor.Component` — behaviour + `use Athanor.Component` macro for
  declaring page-builder components. Optional callbacks: `metadata/0`,
  `default_props/0`, `required_props/0`, `validate/1`, `fields/0`,
  `resolve_fields/2`, `resolve_data/2`, `render/3`, `editor_form/0`,
  `child_zones/1`. Inspired by Puck.js's dynamic fields + data hooks.
- `Athanor.Registry` — runtime lookup of component modules by `type`
  string, sourced from `config :athanor, :components`.
- `Athanor.Ctx` — render/edit context struct carrying `account_id`,
  `brand_id`, `edit_mode?`, callbacks, and a freeform `:extra` map.
- `Athanor.Renderer` — dispatches each node in the tree to its
  component's `render/3` and wraps the result in edit chrome when
  `ctx.edit_mode?`.
- `Athanor.Fields` — auto-renders a component's field schema (text,
  textarea, number, select, color, checkbox, custom) into HTML form
  inputs. Custom fields delegate to consumer-provided LiveComponents.
- `Athanor.Field` — behaviour-style contract for custom field
  LiveComponents (value/on_change/ctx/label/opts assigns).
- `Athanor.AutoEditorForm` — LiveComponent wrapping `Athanor.Fields`
  with the form/state plumbing (phx-change, custom field callbacks).
- `Athanor.Editor` — function components (`canvas`, `components_panel`,
  `config_panel`, `zone_picker_modal`, `shell`) for composing custom
  editor layouts, plus a `@behaviour` for the consumer LiveView.
- `Athanor.Editor.Live` — turn-key `use` macro injecting `mount/3`,
  `render/1`, `handle_event/3`, `handle_info/2`. Consumer implements
  `load/3` and `save/2`; optional overrides for `render_header/1` and
  `render_top_bar_actions/1`.
- `Athanor.Editor.State` — typed struct for editor state (content,
  metadata, ctx, selected_component_id, preview_viewport,
  show_components_panel, column_picker, open_sections).
- Built-in primitive components: `Athanor.Components.Button`,
  `Athanor.Components.Columns`, `Athanor.Components.Divider`,
  `Athanor.Components.Heading`, `Athanor.Components.Text`.
- `Athanor.Components.Formatting` + `Athanor.Components.Formatting.EditorForm`
  — shared formatting tab (alignment / colors / padding / margin /
  borders) reused across every component's config panel. Color swatches
  ship with a Clear button (pure client-side, no JS hooks).
- Page settings as a regular `Athanor.Component`: consumers pass any
  Athanor.Component module as the `:page_settings_component` opt and
  the library auto-renders its `fields/0` at the top of the sidebar.

[Unreleased]: https://github.com/Arsenalist/athanor/compare/v0.1.0-beta.9...HEAD
[0.1.0-beta.9]: https://github.com/Arsenalist/athanor/releases/tag/v0.1.0-beta.9
[0.1.0-beta.3]: https://github.com/Arsenalist/athanor/releases/tag/v0.1.0-beta.3
[0.1.0-beta.2]: https://github.com/Arsenalist/athanor/releases/tag/v0.1.0-beta.2
[0.1.0-beta.1]: https://github.com/Arsenalist/athanor/releases/tag/v0.1.0-beta.1
