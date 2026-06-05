defmodule Athanor.Editor.State do
  @moduledoc """
  Internal state struct owned by `Athanor.Editor.Live`.

  Encapsulates the assigns the library manages on behalf of the consumer:

  - `content`: the editor's node tree, persisted at `editor_content.content`
    in the canonical Athanor shape `%{"content" => [nodes...]}`
  - `metadata`: flat map persisted at `editor_content.metadata` (page-level
    fields edited via the `page_settings_component:` form)
  - `selected_component_id`: id of the currently-selected node (right
    sidebar shows that node's config when set)
  - `column_picker`: `nil | {parent_id, zone_name}` — drives the
    zone-picker modal opened by `Athanor.Components.Columns`'
    per-zone "Add Component" button
  - `preview_viewport`: `:desktop | :tablet | :mobile` — applied as
    max-width class on the canvas wrapper
  - `show_components_panel`: boolean — toggles the left sidebar
  - `ctx`: `Athanor.Ctx` with editor-mode fields populated
    (`edit_mode?: true`, `add_component_callback`, `select_component_callback`)
  """

  defstruct content: %{"content" => []},
            metadata: %{},
            selected_component_id: nil,
            column_picker: nil,
            preview_viewport: :desktop,
            show_components_panel: true,
            ctx: nil,
            asset_request: nil

  @type viewport :: :desktop | :tablet | :mobile

  @type t :: %__MODULE__{
          content: map(),
          metadata: map(),
          selected_component_id: String.t() | nil,
          column_picker: {String.t(), String.t()} | nil,
          preview_viewport: viewport(),
          show_components_panel: boolean(),
          ctx: Athanor.Ctx.t() | nil,
          asset_request: Athanor.Editor.AssetRequest.t() | nil
        }

  @doc """
  Build a default state. Useful for tests and as the seed value the
  Editor LV macro uses before `load/3` fills in real values.
  """
  def new, do: %__MODULE__{}

  @doc """
  Build a state with overrides. Unknown keys raise `KeyError`.
  """
  def new(overrides) when is_list(overrides), do: struct!(__MODULE__, overrides)
  def new(overrides) when is_map(overrides), do: struct!(__MODULE__, Map.to_list(overrides))
end
