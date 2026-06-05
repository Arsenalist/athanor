## Context

Athanor is a host-agnostic page-builder library. A hard physical boundary
(enforced by `test/athanor/tree_architecture_test.exs`) forbids referencing
`Amplify.*`, `AmplifyWeb.*`, `Ecto.*`, or gettext. The host wires app-specific
behaviour through a small set of seams:

- `Athanor.Ctx` — passthrough context + a few pluggable adapter slots.
- `Athanor.Editor` behaviour callbacks (`load/3`, `save/2`, `seed_default_props/3`,
  `render_header/1`, `render_top_bar_actions/1`) implemented by hosts that
  `use Athanor.Editor.Live` (the turn-key editor).
- `Athanor.Component.fields/0` — declarative field schema auto-rendered by
  `Athanor.Fields` inside the config panel.

Today an uploaded image is obtained via a `:custom` field pointing at a host module
(`AmplifyWeb.PageBuilder.Fields.ImagePicker`), which mounts `MediaManager` inline,
reads `ctx` auth, and calls `on_change` with a URL string. This works but: (1) the
component declaration references a host module → not portable; (2) the picker LC is
mounted per-field; (3) value shape is ad-hoc.

Constraints discovered during exploration:

- The turn-key editor's `render/1` and `handle_event/3` are **injected by the macro
  and NOT in `defoverridable`** (`lib/athanor/editor/live.ex:110`). Hosts cannot add
  their own `handle_event` clauses; Athanor's catch-all (`live.ex:386`) silently
  swallows unknown events. So a host cannot receive a bare untargeted event, and has
  no DOM region of its own in the editor.
- The shell primitive (`Athanor.Editor.shell/1`) already exposes a `:modals` slot,
  but `shell_render/1` hardcodes only the library's `zone_picker_modal` into it.
- Amplify's `MediaUploader` (Waffle) already whitelists `.pdf .doc .xls .mp4 .mov …`
  and `MediaManager.on_select_images` already returns a **list** of ids — so
  generalizing to "asset" and supporting `multiple` requires no host upload changes.

## Goals / Non-Goals

**Goals:**

- A built-in, portable `:asset` field requiring zero host module reference in a
  component's `fields/0`.
- Generalize over any uploadable kind (image, pdf, video, …) and any cardinality
  (single, gallery, multi-file).
- Keep Athanor 100% upload-blind: it knows the *intent* ("an asset was requested")
  and a minimal *display contract*, never the *mechanism*.
- Provide both seams the round-trip needs: an **event seam** (host code runs on click)
  and a **DOM seam** (host UI has somewhere to render).
- Bare-minimal default with no host wiring: paste a URL.

**Non-Goals:**

- Athanor performing or knowing about uploads, storage, CDNs, or browse/search UI.
- Athanor rendering a picker modal/table (the inverse of Puck's `external` field —
  deliberately host-owned).
- A `readOnly` field concept (Puck has it; out of scope, noted for later).
- Drag-reorder of gallery items in v1 (reuse existing `athanor:dnd_drop` later).
- Migrating Amplify in this change (follow-up; this change ships the Athanor seams +
  field and documents the integration).

## Decisions

### D1. Built-in `:asset` field, not another `:custom` module

`:custom` is the full escape hatch (host renders everything) and stays. `:asset` is a
first-class declarative type so components stay portable: `{"hero", :asset, accept: "image/*"}`
names no host code. This mirrors Puck's split — declarative built-in field types +
a `custom` override — and is the "heavily-used library" ergonomic: a component library
ships `:asset` fields that work in any host implementing one callback.

**Alternative considered:** keep using `:custom` only. Rejected — forces every
component to hardcode a host picker module; not portable; defeats open-source reuse.

### D2. Host seam is an `Athanor.Editor` behaviour callback, NOT a `Ctx` JS-callback

The existing `add_component_callback`/`select_component_callback` live on `Ctx` and
return `Phoenix.LiveView.JS` because they are emitted by **host-agnostic components**
that render in preview (no editor) *and* in the editor; the callback indirection buys
portability and degrades to nil-hidden in preview.

The `:asset` field is **editor-only** and its action must reach **host** logic. The
correct precedent is therefore `save/2` / `load/3` — host-extension behaviour
callbacks — not the Ctx JS-callbacks. So we add `handle_asset_request/2`. The
existing Ctx callbacks are **not** refactored: they solve a different problem
(portable component chrome), and converting them to bare events would break preview
mode (no handler on the public-page LV; loss of the nil-hidden affordance).

Knowledge level: Athanor learns the intent "an asset was requested for node/key" —
the same epistemic level it already has for `"save"`. It never learns how the host
uploads, exactly as `save/2` never teaches it about Ecto.

**Alternative considered (A):** a `Ctx` callback returning `JS.push(...)`. Rejected —
it would store a host closure (more coupling than a fixed event name), add a Ctx
field, and the turn-key catch-all would still need a route to host code. The callback
indirection's only payoff (host chooses client-side JS) is unneeded; opening a picker
needs a server round-trip anyway.

**Alternative considered (B):** a bare untargeted `phx-click` event the host catches.
Rejected — in the turn-key editor that event lands in Athanor's injected
`handle_event`, hits the catch-all, and is silently dropped; the host cannot add a
competing clause.

### D3. Extensible request payload as a struct

`handle_asset_request/2` receives one `%Athanor.Editor.AssetRequest{}` rather than
positional args, so fields can be added later without breaking arity (BEAM/Elixir
practice for evolving contracts):

```elixir
defmodule Athanor.Editor.AssetRequest do
  @enforce_keys [:node_id, :key]
  defstruct [:node_id, :key, :accept, :multiple, :max, :min, :current]
end
```

`:current` carries the existing value so the host can decide "add to gallery" vs
"replace". Athanor always does a wholesale replace on write-back; the host produces
the final value.

### D4. General `render_outlet/1`, not `render_modals/1`

The round-trip needs a **DOM seam**: somewhere the host renders its picker. The
turn-key host owns no editor markup. We add an optional `render_outlet/1` render
callback (default `~H""`), pre-rendered like `render_header/1` and fed into the
shell's existing `:modals` slot alongside `zone_picker_modal`.

Named `render_outlet` (not `render_modals`) deliberately: it makes no UI-form promise.
A single root-level outlet suffices because modals/drawers/toasts are `position: fixed`
and an offscreen file input is `display:none` — DOM parent is irrelevant, so the
host's own markup + CSS decide the form. The asset picker is merely the first consumer;
future help drawers / comment panels reuse the same outlet with no Athanor change.

**Alternative considered:** `render_modals/1`. Rejected — prescribes "modal" as the
form; the seam is a general host render region.

**Alternative considered:** a brand-new shell slot. Rejected — `:modals` already exists
and fixed-position UI ignores DOM location; reuse it and add only the callback.

### D5. Asset descriptor: opaque map with a minimal display contract

Value is a plain, string-keyed, JSON-serializable map (matches Athanor's
"decoded maps in/out" rule):

```elixir
%{"url" => "...", "name" => "deck.pdf", "content_type" => "application/pdf",
  # opaque host extras Athanor never reads: "alt", "width", "thumb_url", ...}
```

Athanor reads only `url`/`name`/`content_type`, and only for neutral chrome:
`content_type` starting `"image/"` → render a thumbnail; otherwise → filename
(`name`) + a generic icon. `name` doubles as the gallery chip label (Puck's
`getItemSummary`). All other keys pass through untouched for the component's
`render(:live)` to consume. This keeps Athanor type-agnostic: a new kind (video,
3D, audio) needs zero Athanor change — only a different `content_type` from the host.

### D6. Cardinality is Puck-polymorphic (single value vs list)

- `multiple: false` (default) → value is one descriptor map, or `nil`.
- `multiple: true` → value is a list of descriptors, or `[]`. `min`/`max` bound it.

This matches Puck (single fields hold a value; `array` holds a list) and author
intuition. `accept`/`min`/`max` are forwarded to the host in the request and are
**not** enforced by Athanor; only `multiple` affects Athanor's chrome (single preview
slot vs chip list + Add/remove).

## Risks / Trade-offs

- **Polymorphic value shape (map vs list)** → component authors must branch
  (`List.first(assets)` vs `assets`). Mitigation: document clearly; `multiple`
  defaults to false so the common single case is a bare map.
- **Silent no-op when host omits `handle_asset_request/2`** → clicking "Choose" does
  nothing visible, confusing during host bring-up. Mitigation: default behaviour keeps
  the URL-paste input visible/active so the field is never dead; document the callback
  as required to enable picking.
- **`render_outlet/1` is a wide-open render hook** → a host could break editor layout.
  Mitigation: it feeds the fixed-position `:modals` layer; document "fixed/offscreen
  UI only".
- **Descriptor `content_type` may be absent** (host resolves only a URL) → preview
  can't tell image from file. Mitigation: fall back to extension sniffing of `url`
  for the thumbnail heuristic; never error, just show the generic chip.
- **Architecture test breadth** → grepping for `image`/`upload` could false-positive on
  unrelated words. Mitigation: scope the assertion to whole-word, source-only matches
  and the specific forbidden tokens (`MediaUploader`, `allow_upload`,
  `consume_uploaded_entries`).

## Migration Plan

1. Ship Athanor seams + `:asset` field (this change). Fully backward compatible —
   `:custom` and existing pickers untouched; new callbacks are optional with safe
   defaults.
2. Amplify (follow-up, separate repo): implement `handle_asset_request/2` (open
   `MediaManager`, stash `{node_id, key}`) and `render_outlet/1` (mount `MediaManager`),
   resolve selected ids → descriptors via `ImagesContext`, write back through
   `{:update_component_props, …}`.
3. Migrate Amplify components field-by-field: `{"image", :custom, module: ImagePicker}`
   → `{"hero", :asset, accept: "image/*"}`; PageSettings `"image"` likewise.
4. Once all consumers migrated, optionally retire `ImagePicker`.

Rollback: the change is additive; reverting the Athanor commit removes the field type
and callbacks with no data migration (no persisted shape depends on it until a host
adopts `:asset`).

### D7. Amplify migration: value-shape change is the real work

Migrating Amplify's four `ImagePicker` (`:custom`) sites to `:asset` changes the
persisted prop from a **bare URL string** (today `on_change.(url)`) to an **asset
descriptor map** (`%{"url" => ...}`). Every consumer that reads `props["image"]` as a
string is affected:

- `Hero`, `Card`, `ImageConfig` `render(:live)` pass `src={@image}` to `<.image>`,
  expecting a string.
- `PageSettings` `"image"` flows into the typed `page.image` column and is consumed by
  `AmplifyWeb.SeoImpl` (`AmplifyWeb.Image.image(%{src: image})`), which expects a
  string for SEO/OpenGraph tags.

Decisions:

- **Keep the descriptor uniform** (no string-mode `:asset`) to avoid reintroducing
  value polymorphism. Normalize at the Amplify boundary instead.
- **Render read-path tolerates both shapes** during transition: a string (legacy saved
  pages) OR a descriptor (new). Extract via a small helper
  `asset_url(value) :: string | nil` (string passthrough; `descriptor["url"]`
  otherwise). Lives Amplify-side to keep Athanor lean.
- **`PageSettings` extracts the URL on save** into the typed `page.image` column, so
  `SeoImpl` keeps receiving a string and SEO is unaffected. This fits the existing
  `PageSettings` pattern of splitting metadata into typed columns (slug, name_i18n).
- **Back-compat for existing pages**: no data migration. Legacy string values render
  via the string passthrough; they upgrade to descriptors only when re-picked.

### D8. Pending-request lifecycle lives in editor State (open/close)

The turn-key macro injects `handle_event/3` and `handle_info/2` and does **not**
make them overridable (`live.ex` `defoverridable` lists only `seed_default_props`,
`render_header`, `render_top_bar_actions`, `render_outlet`). So a host cannot add
its own `handle_info` clause to track "is the picker open". The picker open/close
state therefore lives in Athanor's `Editor.State` as `asset_request`
(`%AssetRequest{} | nil`), and `render_outlet/1` shows the host picker when it is set.

Athanor only ever knows "a request is pending for node/key" — the intent, never the
upload mechanism. The host's `handle_asset_request/2` may still run for setup, but the
open state is owned by Athanor so close works without a host `handle_info`.

**Precise clear rules** (the load-bearing part — naive "clear on any write" leaks
across unrelated edits, because `update_component_props` carries the whole props map,
not the changed key):

```
SET    asset_request := %AssetRequest{}   on  "athanor_asset_request"
CLEAR  on  "athanor_asset_cancel"                                 (explicit close — REQUIRED)
CLEAR  on  {:update_component_props, node_id, props}
           IFF node_id == pending.node_id
           AND Map.get(props, pending.key) != pending.current     (value actually changed)
CLEAR  on  select_component / close_config / remove_component     (navigation safety net)
NEVER  persist asset_request (State-only; excluded from the save/2 payload)
```

Rationale per rule:

- **value-changed, not node-only**: an unrelated field edit on the same node fires
  `update_component_props` for that node; only the pending key's value actually
  changing signals the picker resolved. Re-selecting the same value is a no-op and is
  dismissed via cancel instead.
- **mandatory cancel**: closing the picker without selecting fires no write-back, so
  without an explicit cancel the pending flag (and thus the picker) would be stuck open.
- **navigation clears**: pending is bound to "configuring this node now"; selecting
  another component, closing the config panel, or removing the node abandons it (and
  removal would otherwise strand a write-back at a missing node).
- **wholesale gallery write**: hosts write the full descriptor list once on select
  (matches Athanor's existing wholesale-replace semantics); incremental per-item writes
  would close the picker early.

### Resolved questions

- `min`/`max` are **host-enforced only** — Athanor forwards them in the request and
  does not validate; keeps the library thin.
- Descriptor uses **string keys** (`"url"`, `"name"`, `"content_type"`) — consistent
  with existing props maps and the JSON-in/out rule.
- `render_outlet/1` receives the **full assigns map** (parity with `render_header/1`).
