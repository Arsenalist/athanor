defmodule Athanor.Editor do
  @moduledoc """
  Editor surface for Athanor — turn-key LiveView + composable primitives
  for building consumer page-builders.

  ## Three usage modes

  ### 1. Turn-key (`use Athanor.Editor.Live`)

  Consumer module becomes the LiveView. Implement `c:load/3` + `c:save/2`,
  optionally override `c:render_header/1` and `c:render_top_bar_actions/1`.

      defmodule MyApp.PageBuilderLive do
        use Athanor.Editor.Live,
          page_settings_component: MyApp.PageSettings

        @impl Athanor.Editor
        def load(params, session, socket) do
          page = MyContext.get_page(params["id"])
          {:ok, %{content: page.content, metadata: page.metadata,
                  ctx_assigns: %{account_id: session["account_id"]}}}
        end

        @impl Athanor.Editor
        def save(socket, %{content: c, metadata: m}) do
          MyContext.save_page(socket.assigns.page, content: c, metadata: m)
        end
      end

  ### 2. Composable (build your own LiveView)

  Use `Athanor.Editor.shell/1` as the layout primitive and fill its slots
  with library LiveComponents (`Athanor.Editor.Canvas`,
  `Athanor.Editor.ComponentsPanel`, `Athanor.Editor.ConfigPanel`,
  `Athanor.Editor.ZonePickerModal`) or your own widgets.

  ### 3. Page-level settings

  Pass any Athanor.Component as `page_settings_component:` and it renders
  at the top of the left sidebar via `Athanor.AutoEditorForm`. Reuses
  every field-schema feature (`fields/0`, `resolve_fields`,
  `resolve_data`, custom field LCs).
  """

  use Phoenix.Component

  alias Athanor.AutoEditorForm
  alias Athanor.Registry
  alias Athanor.Renderer
  alias Athanor.Tree

  # ─── Behaviour callbacks ───────────────────────────────────────────────

  @doc """
  Load initial editor state. Called by the library during `mount/3`.

  Return:
    `{:ok, %{content: tree, metadata: map, ctx_assigns: map}}`
  or:
    `{:error, term}` to abort mount (consumer can short-circuit via
    `push_navigate` etc. in their own mount/3 before delegating).
  """
  @callback load(params :: map(), session :: map(), socket :: Phoenix.LiveView.Socket.t()) ::
              {:ok,
               %{
                 required(:content) => map(),
                 required(:metadata) => map(),
                 required(:ctx_assigns) => map()
               }}
              | {:error, term()}

  @doc """
  Persist the current editor state. Called by the library on `"save"` event.

  Receives `%{content: tree_map, metadata: flat_map}`. Returns
  `{:ok, anything}` for success (library shows success toast) or
  `{:error, term}` for failure (library shows error toast).
  """
  @callback save(socket :: Phoenix.LiveView.Socket.t(),
                  state :: %{required(:content) => map(), required(:metadata) => map()}) ::
              {:ok, any()} | {:error, term()}

  @doc """
  Render the top header bar. Optional — library provides a barebones
  default. Consumers override for branding (back button, brand logo,
  page title display).
  """
  @callback render_header(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Render the right-side action area of the top bar (Save button,
  viewport switcher, etc.). Optional — library provides a default
  with just Save + viewport.
  """
  @callback render_top_bar_actions(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Hook for consumers to seed extra props when a component is first
  added to the canvas. Called as `seed_default_props(component, type,
  socket)` immediately after the library builds the new node from
  `default_props/0`. Optional — default no-op.

  Use cases: injecting `brand_id`/`account_id` into per-page-defaults
  for legacy components that read those props at render time.
  """
  @callback seed_default_props(component :: map(), type :: String.t(),
                                socket :: Phoenix.LiveView.Socket.t()) :: map()

  @optional_callbacks render_header: 1,
                      render_top_bar_actions: 1,
                      seed_default_props: 3

  # ─── shell function component ──────────────────────────────────────────

  @doc """
  Layout primitive for the editor — top bar + 3 columns + modal layer.

  All slot regions are present in the DOM (with stable testids) so
  consumers can mount the same layout shape regardless of which slots
  they fill. Slot contents receive a context map with the editor's
  current display state (`page_title`, `selected_component_id`,
  `viewport`) via `:let={ctx}`.

  ## Slots

  - `:header` — top bar content. Consumer puts back button, title,
    save button, viewport switcher.
  - `:sidebar_left` — left panel. Typical content: page settings form
    (top) + components palette (below).
  - `:sidebar_right` — right panel. Typical content: selected
    component's config form (when a node is selected).
  - `:modals` — floating modal overlay. Library's own zone-picker
    modal renders here from the consumer LV; consumers can stack
    additional modals.
  """
  attr :page_title, :string, default: nil, doc: "Current page title, forwarded to slots."

  attr :selected_component_id, :string,
    default: nil,
    doc: "Selected node id, forwarded to slots."

  attr :viewport, :atom, default: :desktop, doc: "Current preview viewport (:desktop|:tablet|:mobile)."

  attr :show_components_panel, :boolean,
    default: true,
    doc: "When false, hides the left sidebar and renders an expand button in the canvas margin."

  slot :header
  slot :sidebar_left
  slot :sidebar_right
  slot :modals
  slot :inner_block, doc: "Canvas region content."

  def shell(assigns) do
    slot_ctx = %{
      page_title: assigns.page_title,
      selected_component_id: assigns.selected_component_id,
      viewport: assigns.viewport
    }

    assigns = assign(assigns, :slot_ctx, slot_ctx)

    ~H"""
    <div data-testid="athanor-editor-shell" class="flex flex-col h-screen bg-base-200">
      <div
        data-testid="athanor-editor-header"
        class="sticky top-0 z-20 bg-base-100/95 backdrop-blur border-b border-base-300/60 shadow-sm"
      >
        {render_slot(@header, @slot_ctx)}
      </div>

      <div class="flex flex-1 min-h-0">
        <aside
          :if={@show_components_panel}
          data-testid="athanor-editor-sidebar-left"
          class="w-72 shrink-0 border-r border-base-300/60 bg-base-100 overflow-y-auto"
        >
          {render_slot(@sidebar_left, @slot_ctx)}
        </aside>

        <main
          data-testid="athanor-editor-canvas"
          class="flex-1 overflow-auto relative"
        >
          <div
            :if={!@show_components_panel}
            class="sticky top-0 z-30 flex items-center px-4 py-2 bg-base-100/95 backdrop-blur border-b border-base-300/60"
          >
            <button
              type="button"
              data-testid="expand-components-panel"
              phx-click="toggle_components_panel"
              aria-label="Expand components panel"
              class="h-8 px-3 inline-flex items-center gap-2 rounded-md text-xs font-medium text-base-content/70 hover:bg-base-200 hover:text-base-content cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
            >
              <i class="fas fa-chevron-right text-[10px]" aria-hidden="true"></i>
              Show components panel
            </button>
          </div>
          <div class="px-6 py-8">
            {render_slot(@inner_block, @slot_ctx)}
          </div>
        </main>

        <aside
          data-testid="athanor-editor-sidebar-right"
          class={[
            "w-96 shrink-0 border-l border-base-300/60 bg-base-100 overflow-y-auto",
            if(@selected_component_id, do: "", else: "hidden")
          ]}
        >
          {render_slot(@sidebar_right, @slot_ctx)}
        </aside>
      </div>

      <div data-testid="athanor-editor-modals">
        {render_slot(@modals, @slot_ctx)}
      </div>
    </div>
    """
  end

  # ─── canvas function component ─────────────────────────────────────────

  @doc """
  Renders the editor canvas — iterates the content tree, wraps each
  top-level node with edit chrome (Configure button + selection
  border), dispatches per-node rendering via
  `Athanor.Renderer.node_component/1`.

  Children of container nodes (Columns zones) get their OWN edit chrome
  from the container's render(:live, edit_mode=true) — the library
  Columns renders the per-zone "Add Component" button and per-child
  Configure button when ctx.edit_mode? + ctx.select_component_callback
  are set.
  """
  attr :content, :map, required: true, doc: "editor_content map (must have \"content\" key)"
  attr :ctx, Athanor.Ctx, required: true
  attr :selected_component_id, :string, default: nil
  attr :viewport, :atom, default: :desktop, doc: ":desktop | :tablet | :mobile"

  def canvas(assigns) do
    nodes = Map.get(assigns.content, "content", [])

    assigns =
      assigns
      |> assign(:nodes, nodes)
      |> assign(:viewport_class, viewport_class(assigns.viewport))

    ~H"""
    <div data-testid="athanor-canvas" class={["mx-auto", @viewport_class]}>
      <%= if @nodes == [] do %>
        <div
          class="flex flex-col items-center justify-center text-center py-16 px-6 rounded-xl border-2 border-dashed border-base-300 bg-base-100/40"
          data-testid="athanor-canvas-empty"
        >
          <div class="w-12 h-12 rounded-full bg-base-200 flex items-center justify-center mb-3">
            <i class="fas fa-cube text-base-content/40"></i>
          </div>
          <p class="text-sm font-medium text-base-content/70">No components yet</p>
          <p class="text-xs text-base-content/50 mt-1">Pick one from the left panel to begin.</p>
        </div>
      <% else %>
        <div class="flex flex-col gap-3">
          <div
            :for={node <- @nodes}
            class="group/canvas-item relative"
            data-testid="athanor-canvas-item"
          >
            <div
              :if={@ctx.select_component_callback != nil}
              class="absolute -top-3 right-2 z-10 opacity-0 group-hover/canvas-item:opacity-100 focus-within:opacity-100 transition-opacity"
            >
              <button
                type="button"
                data-testid={"athanor-canvas-configure-" <> node["id"]}
                phx-click={@ctx.select_component_callback.(node["id"])}
                phx-value-id={node["id"]}
                aria-label={"Configure component " <> node["id"]}
                class={[
                  "h-8 px-3 inline-flex items-center gap-1.5 rounded-md text-xs font-medium shadow-sm border cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40",
                  if(node["id"] == @selected_component_id,
                    do: "bg-primary text-primary-content border-primary",
                    else: "bg-base-100 text-base-content border-base-300 hover:bg-base-200"
                  )
                ]}
              >
                <i class="fas fa-cog text-[10px]" aria-hidden="true"></i> Configure
              </button>
            </div>
            <div
              class={[
                "rounded-lg border-2 p-3 bg-base-100 transition-colors",
                if(node["id"] == @selected_component_id,
                  do: "border-primary",
                  else: "border-transparent group-hover/canvas-item:border-base-300"
                )
              ]}
            >
              <Renderer.node_component
                node={node}
                ctx={@ctx}
                edit_mode={@ctx.edit_mode? == true}
                show_config={false}
                selected_component_id={@selected_component_id}
              />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp viewport_class(:tablet), do: "max-w-[768px]"
  defp viewport_class(:mobile), do: "max-w-[375px]"
  defp viewport_class(_), do: ""

  # ─── components_panel function component ───────────────────────────────

  @doc """
  Left-sidebar content. Renders the components palette from
  `Athanor.Registry.components_metadata/0` and, when
  `page_settings_component` is provided, renders that component's form
  via `Athanor.AutoEditorForm` ABOVE the palette.
  """
  attr :ctx, Athanor.Ctx, required: true
  attr :page_settings_component, :atom, default: nil
  attr :metadata, :map, default: %{}

  def components_panel(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex items-center justify-end px-3 pt-3">
        <button
          type="button"
          data-testid="toggle-components-panel"
          phx-click="toggle_components_panel"
          aria-label="Collapse components panel"
          class="h-7 w-7 inline-flex items-center justify-center rounded-md text-base-content/40 hover:bg-base-200 hover:text-base-content cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
        >
          <i class="fas fa-chevron-left text-xs" aria-hidden="true"></i>
        </button>
      </div>
      <section :if={@page_settings_component} data-testid="page-settings">
        <header class="sticky top-0 z-10 flex items-center gap-2 px-4 py-3 bg-base-100 border-b border-base-300/60">
          <i class={"fas #{page_settings_icon(@page_settings_component)} text-xs text-base-content/40"}></i>
          <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            {page_settings_label(@page_settings_component)}
          </h2>
        </header>
        <div class="px-4 py-4 border-b border-base-300/60">
          <.live_component
            module={AutoEditorForm}
            id="page-settings-form"
            component_id="page-settings"
            component_module={@page_settings_component}
            props={@metadata}
            ctx={@ctx}
            show_formatting={false}
          />
        </div>
      </section>

      <section data-testid="components-palette">
        <header class="sticky top-0 z-10 flex items-center gap-2 px-4 py-3 bg-base-100 border-b border-base-300/60">
          <i class="fas fa-puzzle-piece text-xs text-base-content/40"></i>
          <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Components
          </h2>
        </header>
        <div class="px-3 py-3">
          <div class="grid grid-cols-2 gap-2">
            <button
              :for={meta <- Registry.components_metadata()}
              type="button"
              phx-click="add_component"
              phx-value-type={meta.type}
              aria-label={"Add #{meta.label} component"}
              class="group flex flex-col items-center gap-1.5 px-2 py-3 min-h-[88px] rounded-lg bg-base-200/50 hover:bg-primary/5 border border-transparent hover:border-primary/30 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40 transition-colors duration-150"
            >
              <div class="w-9 h-9 rounded-md flex items-center justify-center bg-base-100 border border-base-300/40 group-hover:border-primary/40 group-hover:bg-primary/10 text-base-content/70 group-hover:text-primary transition-colors">
                <i class={["fas", Map.get(meta, :icon, "fa-cube"), "text-sm"]} aria-hidden="true"></i>
              </div>
              <span class="text-[11px] font-medium text-base-content text-center leading-tight">
                {meta.label}
              </span>
            </button>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp page_settings_label(module) do
    case module.metadata() do
      %{label: label} -> label
      _ -> "Page Settings"
    end
  end

  defp page_settings_icon(module) do
    case module.metadata() do
      %{icon: icon} when is_binary(icon) -> icon
      _ -> "fa-file-alt"
    end
  end

  # ─── config_panel function component ───────────────────────────────────

  @doc """
  Right-sidebar content. Renders the selected component's config form
  via `Athanor.AutoEditorForm` when the selected node's module declares
  `fields/0`. Falls back to the legacy `editor_form/0` LC when set,
  or to a "no configuration needed" placeholder when neither applies.
  Renders nothing when nothing is selected (parent shell hides the
  sidebar region in that case).
  """
  attr :selected_component_id, :string, default: nil
  attr :content, :map, required: true
  attr :ctx, Athanor.Ctx, required: true

  def config_panel(assigns) do
    node =
      if assigns.selected_component_id do
        case Tree.find(assigns.content, assigns.selected_component_id) do
          {:ok, found} -> found
          :error -> nil
        end
      end

    assigns = assign(assigns, :node, node)

    ~H"""
    <div :if={@node} data-testid="component-config" class="flex flex-col">
      <header class="sticky top-0 z-10 flex items-center gap-2 px-4 py-3 bg-base-100 border-b border-base-300/60">
        <i class="fas fa-sliders text-xs text-base-content/40"></i>
        <h2 class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
          {component_label(@node)}
        </h2>
        <div class="ml-auto flex items-center gap-1">
          <button
            type="button"
            data-testid="component-config-delete"
            phx-click="remove_component"
            phx-value-id={@node["id"]}
            data-confirm="Delete this component?"
            aria-label="Delete component"
            class="h-8 w-8 rounded-md flex items-center justify-center text-base-content/40 hover:bg-error/10 hover:text-error cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error/40"
          >
            <i class="fas fa-trash text-xs" aria-hidden="true"></i>
          </button>
          <button
            type="button"
            phx-click="close_config"
            aria-label="Close configuration panel"
            class="h-8 w-8 rounded-md flex items-center justify-center text-base-content/40 hover:bg-base-200 hover:text-base-content cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
          >
            <i class="fas fa-times text-xs" aria-hidden="true"></i>
          </button>
        </div>
      </header>
      <div class="px-4 py-4">
        <.config_dispatch node={@node} ctx={@ctx} />
      </div>
    </div>
    """
  end

  defp component_label(node) do
    type = node["type"]

    case Registry.lookup(type) do
      nil -> String.capitalize(type || "Component")
      mod -> Map.get(mod.metadata(), :label, String.capitalize(type))
    end
  end

  attr :node, :map, required: true
  attr :ctx, Athanor.Ctx, required: true

  defp config_dispatch(assigns) do
    type = assigns.node["type"]
    mod = Registry.lookup(type)

    decision =
      cond do
        is_nil(mod) ->
          :none

        function_exported?(mod, :fields, 0) and mod.fields() != [] ->
          {:fields, mod}

        function_exported?(mod, :editor_form, 0) and mod.editor_form() != nil ->
          {:editor_form, mod.editor_form()}

        true ->
          :none
      end

    {decision_kind, decision_module} =
      case decision do
        {:fields, m} -> {:fields, m}
        {:editor_form, m} -> {:editor_form, m}
        :none -> {:none, nil}
      end

    assigns =
      assigns
      |> assign(:decision_kind, decision_kind)
      |> assign(:decision_module, decision_module)

    ~H"""
    <.live_component
      :if={@decision_kind == :fields}
      module={AutoEditorForm}
      id={"athanor-auto-form-" <> @node["id"]}
      component_id={@node["id"]}
      component_module={@decision_module}
      props={@node["props"]}
      ctx={@ctx}
    />
    <.live_component
      :if={@decision_kind == :editor_form}
      module={@decision_module}
      id={"athanor-editor-form-" <> @node["id"]}
      component_id={@node["id"]}
      props={@node["props"]}
      ctx={@ctx}
      show_config={true}
      edit_mode={true}
    />
    <div
      :if={@decision_kind == :none}
      class="text-sm text-gray-500"
      data-testid="component-no-config"
    >
      No configuration needed for this component.
    </div>
    """
  end

  # ─── zone_picker_modal function component ──────────────────────────────

  @doc """
  Floats a modal layer for adding a component into a Columns zone.
  Rendered into the shell's `:modals` slot by consumer LVs when
  `column_picker` is set to `{parent_id, zone_name}`. On submit emits
  `"add_component_to_zone"` with the parent + zone + chosen type.
  """
  attr :column_picker, :any,
    required: true,
    doc: "nil OR {parent_id :: String.t(), zone_name :: String.t()}"

  def zone_picker_modal(assigns) do
    ~H"""
    <div :if={@column_picker} class="modal modal-open" data-testid="zone-picker-modal">
      <div class="modal-box">
        <% {parent_id, zone_name} = @column_picker %>
        <h3 class="font-bold mb-3">Add a component to "{zone_name}"</h3>
        <form phx-submit="add_component_to_zone" class="flex flex-col gap-3">
          <input type="hidden" name="parent_id" value={parent_id} />
          <input type="hidden" name="zone_name" value={zone_name} />
          <select name="type" class="select select-bordered">
            <option :for={meta <- Registry.components_metadata()} value={meta.type}>
              {meta.label}
            </option>
          </select>
          <div class="flex justify-end gap-2">
            <button
              type="button"
              class="btn btn-ghost"
              phx-click="cancel_zone_picker"
            >
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">Add</button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
