## Why

Components today can only get an uploaded file (image, PDF, video) by declaring a
`:custom` field that names a **host-specific** picker module
(`module: AmplifyWeb.PageBuilder.Fields.ImagePicker`). That couples portable,
open-source component definitions to one host app, mounts a heavy picker
LiveComponent inline per field, and gives every picker its own ad-hoc value shape.
Athanor needs a built-in, host-agnostic field for "an uploaded asset" — one that
ships a zero-dependency default, generalizes beyond images, and lets each host plug
its own upload/browse mechanism without Athanor ever learning what "upload" means.

## What Changes

- Add a built-in `:asset` field type to `Athanor.Fields`. Components declare
  `{"hero", :asset, accept: "image/*"}` with **no host module reference** — portable
  across any host.
- Generalize beyond images: `:asset` carries an opaque `accept:` hint (forwarded, not
  enforced) and supports `multiple:`/`min:`/`max:` for galleries and multi-file
  (PDFs, video, anything the host's uploader accepts).
- Define a stable, JSON-serializable **asset descriptor** value contract:
  `%{"url" => ..., "name" => ..., "content_type" => ...}` plus opaque host extras.
  Single field → one descriptor (or `nil`); `multiple` → list of descriptors (or `[]`).
- Add `%Athanor.Editor.AssetRequest{}` struct and an optional
  `c:Athanor.Editor.handle_asset_request/2` callback. The `:asset` field emits a
  fixed `"athanor_asset_request"` event; Athanor routes it to the host callback.
  Default (no host impl) is a no-op, so the field degrades to paste-a-URL — the
  bare-minimal default.
- Add an optional, **general** `c:Athanor.Editor.render_outlet/1` render callback
  (default empty) fed into the shell's existing `:modals` slot. Gives turn-key hosts
  a DOM seam to render arbitrary chrome (asset picker, drawer, toast, offscreen file
  input). Not asset-specific.
- Write-back rides the existing `{:update_component_props, node_id, props}` channel —
  no new return path.
- Architecture test asserts Athanor source names no upload concept
  (`upload`, `image`, `pdf`, `MediaUploader`, `allow_upload`).

No breaking changes. The existing `:custom` field and host pickers keep working;
hosts migrate `{"image", :custom, module: ImagePicker}` → `{"hero", :asset, accept: "image/*"}`
incrementally.

## Capabilities

### New Capabilities

- `asset-field`: the built-in `:asset` field type — declaration options
  (`accept`/`multiple`/`min`/`max`/`label`/`if`), the asset-descriptor value contract,
  cardinality rules, the editor preview/chip chrome, the request signal, and write-back.
- `editor-extension-points`: host-facing editor seams that the asset field relies on —
  the `%Athanor.Editor.AssetRequest{}` struct, the optional `handle_asset_request/2`
  behaviour callback with event routing, and the general optional `render_outlet/1`
  render callback feeding the shell `:modals` slot.

### Modified Capabilities

(none — `openspec/specs/` is empty; this is the first captured capability set)

## Impact

- **Athanor (this repo)**: `lib/athanor/fields.ex` (new `:asset` field clause),
  `lib/athanor/component.ex` (`field_type` typespec adds `:asset`),
  `lib/athanor/editor.ex` (new `AssetRequest` struct, `handle_asset_request/2` +
  `render_outlet/1` callbacks, shell wiring), `lib/athanor/editor/live.ex`
  (event route, callback delegation + defaults, `defoverridable`). New
  architecture-test assertions in `test/athanor/tree_architecture_test.exs`.
- **Amplify (../amplify) — IN SCOPE for this change**: implement
  `handle_asset_request/2` and `render_outlet/1` in `AmplifyWeb.PageBuilderLive`,
  mount `MediaManager` in the outlet, resolve selected ids to descriptors via
  `ImagesContext`. Reuses the existing Waffle `MediaUploader` (already accepts
  pdf/doc/video) and `MediaManager` (already returns a list of ids) with no
  upload-mechanics changes. Migrate all **four** `ImagePicker` (`:custom`) call-sites
  to `:asset`:
  - `page_builder/page_settings.ex` — `"image"` (Social Image; extract URL into the
    typed `page.image` column on save so `SeoImpl` keeps a string)
  - `page_builder/components/image_config.ex` — `"image"` (required)
  - `page_builder/components/hero.ex` — `"image"` (optional)
  - `page_builder/components/card.ex` — `"image"` (optional)

  Each component's `render(:live)` updates to read the asset URL via a string|descriptor
  tolerant helper (back-compat for legacy saved pages). `ImagePicker` is retired once
  all four are migrated. `TranslatableInput`, `RichTextField`, `ProductPicker`,
  `EventSourceSelector`, `SocialLinksToggles` are **not** image pickers — out of scope.
- **Dependencies**: none added. Athanor stays free of Ecto/Amplify/upload libraries.
