# Tasks — add-asset-field (TDD, test-first)

Each implementation group is preceded by its failing tests (Red), then the minimal
code to pass (Green), then cleanup (Refactor). Do not write implementation before its
test exists and fails. Run `mix test <file>` after each step; run `mix test` before
closing each group.

## 1. AssetRequest struct (editor-extension-points)

- [x] 1.1 RED: add `test/athanor/editor/asset_request_test.exs` — assert
      `%Athanor.Editor.AssetRequest{node_id: "n", key: "k"}` builds; assert building
      without `:node_id` or `:key` raises (enforced keys); assert `accept`, `multiple`,
      `min`, `max`, `current` default to `nil`. Run it; confirm it fails (module
      undefined).
- [x] 1.2 GREEN: create `lib/athanor/editor/asset_request.ex` with
      `@enforce_keys [:node_id, :key]` and `defstruct [:node_id, :key, :accept, :multiple, :max, :min, :current]`.
      Run 1.1; confirm green.
- [x] 1.3 REFACTOR: add `@type t` and a short `@moduledoc`. Re-run; still green.

## 2. `:asset` recognized as a field type

- [x] 2.1 RED: in `test/athanor/component_test.exs` (or a new
      `component_fields_test.exs` case) assert the documented field types include
      `:asset` (typespec/doc parity check consistent with how existing types are
      asserted). Confirm it fails.
- [x] 2.2 GREEN: add `:asset` to the `field_type` typespec in
      `lib/athanor/component.ex` and update the `fields/0` doc list. Confirm green.

## 3. `:asset` field rendering — single value (asset-field)

- [x] 3.1 RED: in `test/athanor/fields_test.exs` add cases:
      (a) declaring `{"hero", :asset, accept: "image/*"}` renders an element with a
      stable asset testid and no `module:`;
      (b) value `%{"url"=>"u","name"=>"n","content_type"=>"image/png"}` renders a
      thumbnail `<img src="u">`;
      (c) value with `content_type "application/pdf"` renders the `"name"` chip and no
      `<img>` thumbnail;
      (d) missing `content_type` but `url` ending `.png` still renders a thumbnail;
      (e) opaque extra keys (`"alt"`) are not dropped from the rendered value/state.
      Confirm all fail.
- [x] 3.2 GREEN: add a `defp field(%{type: :asset} = assigns)` clause to
      `lib/athanor/fields.ex` rendering the single-value preview + a choose control +
      a URL input. Implement the `content_type`/extension thumbnail heuristic.
      Confirm 3.1 green.
- [x] 3.3 RED: add a case asserting the choose control emits a `"athanor_asset_request"`
      with `phx-value` carrying the field `key` and **no** `phx-target`. Confirm fails.
- [x] 3.4 GREEN: wire the event/attrs on the choose control. Confirm green.
- [x] 3.5 RED: add a case asserting the `if:` predicate hides the `:asset` field when
      false (parity with built-ins). Confirm fails, then GREEN via existing
      `visible?/2` path (likely already covered — adjust only if needed).

## 4. `:asset` field rendering — multiple (gallery)

- [x] 4.1 RED: in `test/athanor/fields_test.exs` add cases for `multiple: true`:
      (a) value `[]` renders an add control and zero chips;
      (b) value `[d1, d2]` renders two chips labelled by each `"name"` plus per-item
      remove controls and an add control;
      (c) the add control emits `"athanor_asset_request"` carrying `key`.
      Confirm fail.
- [x] 4.2 GREEN: extend the `:asset` clause to branch on `opts[:multiple]` for the
      chip-list chrome. Confirm green.

## 5. URL-paste default (no host picker)

- [x] 5.1 RED: add a `fields_test.exs` case asserting the URL input is present for an
      `:asset` field and that submitting a URL yields a descriptor whose `"url"` is the
      entered string (drive through the form's change path used by other built-ins).
      Confirm fails.
- [x] 5.2 GREEN: ensure the URL input participates in the existing `update_props`
      form path and normalizes a bare URL into a descriptor map. Confirm green.

## 6. Write-back re-render

- [x] 6.1 RED: add a `fields_test.exs` (or `auto_editor_form_test.exs`) case asserting
      that replacing the field value with a new descriptor re-renders the preview from
      the value (no field-local state retained). Confirm fails (or document if already
      satisfied by statelessness).
- [x] 6.2 GREEN: confirm the `:asset` clause is stateless and reads only `props[key]`;
      adjust if it holds state. Confirm green.

## 7. `render_outlet/1` general render callback (editor-extension-points)

- [x] 7.1 RED: in `test/athanor/editor/live_test.exs` (and/or `shell_test.exs`) assert:
      (a) a generated turn-key module lists `render_outlet: 1` among `defoverridable`
      alongside `render_header`, `render_top_bar_actions`, `seed_default_props`;
      (b) default `render_outlet/1` contributes no visible markup;
      (c) a consumer override's markup appears within the editor `:modals` layer
      (testid `athanor-editor-modals`). Confirm fail.
- [x] 7.2 GREEN: add `render_outlet/1` to the `Athanor.Editor` behaviour as
      `@optional_callbacks`; inject a default in the `__using__` macro
      (`lib/athanor/editor/live.ex`) returning `~H""`; add to `defoverridable`;
      pre-render it in `shell_render/1` and emit it inside the `:modals` slot next to
      `zone_picker_modal`. Confirm 7.1 green.
- [x] 7.3 REFACTOR: confirm `render_outlet/1` receives the full assigns map (parity
      with `render_header/1`); document the "fixed/offscreen UI only" guidance in the
      `Athanor.Editor` moduledoc.

## 8. `handle_asset_request/2` routing (editor-extension-points)

- [x] 8.1 RED: in `test/athanor/editor/live_test.exs` (or `handlers_test.exs`) assert:
      (a) `"athanor_asset_request"` with params `{key, ...}` is routed to
      `consumer.handle_asset_request/2` with a built `%AssetRequest{}` (use a test
      consumer module that records the call);
      (b) when the consumer does not export `handle_asset_request/2`, the event is
      handled with no error and no crash (no-op). Confirm fail.
- [x] 8.2 GREEN: add `handle_asset_request/2` to the `Athanor.Editor` behaviour
      (`@optional_callbacks`); add a `handle_event(consumer, "athanor_asset_request", params, socket)`
      clause in `Athanor.Editor.Live` that builds the `%AssetRequest{}` (from params +
      selected node/key) and dispatches to the consumer if exported, else no-ops.
      Confirm 8.1 green.
- [x] 8.3 REFACTOR: ensure the new clause sits before the catch-all
      (`handle_event(_consumer, _event, _params, socket)`) so it is not swallowed.

## 9. Architecture guard (editor-extension-points)

- [x] 9.1 RED: in `test/athanor/tree_architecture_test.exs` add an assertion that
      `lib/` source contains no `MediaUploader`, `allow_upload`, or
      `consume_uploaded_entries` and does not leak an "upload" notion. Confirm it
      passes already OR fails only if new code introduced a forbidden token; keep it as
      a standing guard.
- [x] 9.2 GREEN: if 9.1 fails, remove the offending reference from the new code (it
      must not exist). Confirm green.

## 9b. Pending asset-request lifecycle (editor-extension-points)

Option A — Athanor owns the picker open/close state in `Editor.State`, since the
turn-key macro does not make `handle_info`/`handle_event` overridable.

- [x] 9b.1 RED: in `test/athanor/editor/state_test.exs` assert `State.new().asset_request == nil`
      and that `State.new(asset_request: req)` round-trips. Confirm fails.
- [x] 9b.2 GREEN: add `asset_request: nil` to `Athanor.Editor.State` defstruct + `@type`.
      Thread it through `current_state/1` and `assign_state/2` in `Athanor.Editor.Live`
      so it lives in socket assigns (visible to `render_outlet/1`). Confirm green.
- [x] 9b.3 RED: in `live_test.exs` assert `"athanor_asset_request"` sets
      `socket.assigns.asset_request` to the built `%AssetRequest{}` (independent of
      whether the consumer implements `handle_asset_request/2`). Confirm fails.
- [x] 9b.4 GREEN: in the `"athanor_asset_request"` handler set
      `state.asset_request` before (optionally) calling the consumer callback. Confirm green.
- [x] 9b.5 RED: assert clear rules — (a) `"athanor_asset_cancel"` clears;
      (b) `{:update_component_props, node, props}` clears IFF `node == pending.node_id`
      AND `props[pending.key] != pending.current`; (c) an unrelated-key write on the
      same node does NOT clear; (d) page-settings write-back clears the same way;
      (e) `select_component`/`close_config`/`remove_component` clear. Confirm fails.
- [x] 9b.6 GREEN: add the `"athanor_asset_cancel"` handler; add `maybe_clear_asset_request/3`
      to both `update_component_props` `handle_info` clauses; clear `asset_request` in
      `do_select_component`/`do_close_config`/`do_remove_component`. Confirm green.
- [x] 9b.7 REFACTOR: confirm `asset_request` is excluded from the `save/2` payload
      (it is State-only, never merged into content/metadata). Add/confirm a test.

## 10. Docs + full suite

- [x] 10.1 Update `Athanor.Field`/`Athanor.Fields`/`Athanor.Component` moduledocs and
      the `fields/0` examples to document `:asset` (opts `accept`/`multiple`/`min`/`max`),
      the descriptor contract, the URL-paste default, `handle_asset_request/2`, and
      `render_outlet/1`. (Docs only — covered behavior already tested above.)
- [x] 10.2 Run full `mix test`; confirm green. Run `mix format` and any credo/dialyzer
      gate the repo uses.
- [x] 10.3 Run `openspec validate add-asset-field --strict` and fix any spec/format
      issues.

---

# Amplify migration (../amplify) — IN SCOPE

Do this only after groups 1–9 are green and Athanor is published/path-available to
amplify. Same TDD discipline: test first.

## 11. Asset-URL read helper + back-compat (amplify)

- [x] 11.1 RED: add `test/amplify_web/page_builder/asset_test.exs` asserting a helper
      `asset_url/1` returns the string unchanged for a legacy string value, returns
      `descriptor["url"]` for a descriptor map, and returns `nil` for `nil`/`""`/
      shapeless input. Confirm fails.
- [x] 11.2 GREEN: implement the `asset_url/1` helper (e.g.
      `AmplifyWeb.PageBuilder.Asset`). Confirm green.

## 12. Host seams in PageBuilderLive (amplify)

- [x] 12.1 RED: in `test/amplify_web/live/page_builder_live_test.exs` assert
      `render_outlet/1` is overridden (MediaManager markup present in the editor modal
      layer) and that dispatching `"athanor_asset_request"` opens the picker (assign
      flips; pending `{node_id, key}` stashed). Confirm fails.
- [x] 12.2 GREEN: implement `handle_asset_request/2` (stash `{node_id, key}` from the
      `%AssetRequest{}`, open MediaManager) and `render_outlet/1` (mount MediaManager
      gated on the open assign), reading auth from existing socket assigns. Confirm green.
- [x] 12.3 RED: assert MediaManager selection (`on_select_images` with one or more ids)
      resolves ids → descriptors via `ImagesContext` and writes back via
      `{:update_component_props, node_id, %{key => descriptor | [descriptors]}}`,
      honoring the request's `multiple`. Confirm fails.
- [x] 12.4 GREEN: implement id→descriptor resolution (`%{"url"=>img.url, "name"=>...,
      "content_type"=>...}`) and the write-back. Confirm green.

## 13. Migrate component fields string→descriptor (amplify)

For each component: update its existing test FIRST to expect the `:asset` field decl
and the descriptor-aware render, then change the component.

- [x] 13.1 RED: `hero` test — `fields/0` declares `{"image", :asset, accept: "image/*"}`
      (no `ImagePicker` module); `render(:live)` shows the image for BOTH a legacy
      string `props["image"]` and a descriptor `%{"url"=>...}`. Confirm fails.
- [x] 13.2 GREEN: migrate `hero.ex` field decl + `render(:live)` via `asset_url/1`.
      Confirm green.
- [x] 13.3 RED+GREEN: same for `card.ex` (optional image).
- [x] 13.4 RED+GREEN: same for `image_config.ex` (required image — keep
      `required_props ["image"]`; ensure validation treats a descriptor as present).
- [x] 13.5 RED: `page_settings` test — `"image"` declared `:asset`; on `save`, the
      descriptor URL is extracted into the typed `page.image` column (string), so
      `SeoImpl` still receives a string; legacy string metadata still saves. Confirm
      fails.
- [x] 13.6 GREEN: migrate `page_settings.ex` field decl + the metadata→`page.image`
      URL extraction in the save split. Confirm green.

## 14. Retire ImagePicker + verify (amplify)

- [x] 14.1 Confirm no remaining references to
      `AmplifyWeb.PageBuilder.Fields.ImagePicker` (grep). Remove
      `fields/image_picker.ex` and its test.
- [x] 14.2 Run full amplify `mix test`; manually verify in the page builder: pick a
      single image (hero/card/image_config), pick the social image (page settings),
      and confirm a legacy page with string image URLs still renders.
- [x] 14.3 `mix format`; repo credo/dialyzer gates green in amplify.
