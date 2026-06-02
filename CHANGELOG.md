# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While the version is in the `0.x` range, any release MAY contain breaking
changes; the minor version is bumped for each one. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full policy.

## [Unreleased]

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

[Unreleased]: https://github.com/Arsenalist/athanor/compare/v0.1.0-beta.1...HEAD
[0.1.0-beta.1]: https://github.com/Arsenalist/athanor/releases/tag/v0.1.0-beta.1
