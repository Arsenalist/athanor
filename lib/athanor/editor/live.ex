defmodule Athanor.Editor.Live do
  @moduledoc """
  Turn-key LiveView for Athanor editor consumers.

  ## Usage

      defmodule MyApp.PageBuilderLive do
        use Athanor.Editor.Live,
          page_settings_component: MyApp.PageSettings  # optional

        @impl Athanor.Editor
        def load(params, session, socket) do
          page = MyContext.get_page(params["id"])
          {:ok, %{content: page.content, metadata: page.metadata,
                  ctx_assigns: %{account_id: session["account_id"]}}}
        end

        @impl Athanor.Editor
        def save(socket, %{content: c, metadata: m}) do
          MyContext.save(socket.assigns.page, content: c, metadata: m)
        end

        # Optional overrides:
        # def render_header(assigns), do: ~H"..."
        # def render_top_bar_actions(assigns), do: ~H"..."
        # def seed_default_props(component, type, socket), do: component
      end

  ## What the macro injects

  - `mount/3` → reads consumer's `load/3`, builds `Athanor.Editor.State`,
    assigns library-owned keys onto the socket
  - `render/1` → composes `Athanor.Editor.shell/1` with all 4 slots
    filled with library function components (canvas, components_panel,
    config_panel, zone_picker_modal). Consumer-overridable
    `render_header/1` + `render_top_bar_actions/1` are called inside
    the `:header` slot.
  - `handle_event/3` → routes editor events (`select_component`,
    `add_component`, `save`, etc.) to internal handlers in this module
  - `handle_info/2` → routes `:update_component_props` messages from
    `AutoEditorForm` into either `:content` or `:metadata` assign
    (page-settings → metadata; everything else → content tree)
  - Default `render_header/1` + `render_top_bar_actions/1`, both
    `defoverridable`

  The macro stays thin — every real implementation lives in this
  module's public functions (`build_initial_state/2`,
  `do_select_component/2`, etc.) so logic is unit-testable without a
  full LiveView mount.
  """

  use Phoenix.Component

  require Logger

  alias Athanor.Ctx
  alias Athanor.Editor.State
  alias Athanor.Tree

  @viewport_values [:desktop, :tablet, :mobile]
  @viewport_strings ~w(desktop tablet mobile)

  # ─── __using__/1 macro ─────────────────────────────────────────────────

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Phoenix.LiveView
      use Phoenix.Component

      @behaviour Athanor.Editor

      @athanor_editor_opts opts
      def athanor_editor_opts, do: @athanor_editor_opts

      @impl Phoenix.LiveView
      def mount(params, session, socket),
        do: Athanor.Editor.Live.mount(__MODULE__, params, session, socket)

      @impl Phoenix.LiveView
      def render(assigns) do
        consumer = __MODULE__
        page_settings = Keyword.get(@athanor_editor_opts, :page_settings_component)

        assigns =
          assigns
          |> Phoenix.Component.assign(:__consumer__, consumer)
          |> Phoenix.Component.assign(:__page_settings__, page_settings)

        Athanor.Editor.Live.shell_render(assigns)
      end

      @impl Phoenix.LiveView
      def handle_event(event, params, socket),
        do: Athanor.Editor.Live.handle_event(__MODULE__, event, params, socket)

      @impl Phoenix.LiveView
      def handle_info(msg, socket),
        do: Athanor.Editor.Live.handle_info(__MODULE__, msg, socket)

      # Default no-op seed.
      def seed_default_props(component, _type, _socket), do: component

      # Default header / actions (overridable).
      def render_header(assigns),
        do: Athanor.Editor.Live.default_render_header(assigns)

      def render_top_bar_actions(assigns),
        do: Athanor.Editor.Live.default_render_top_bar_actions(assigns)

      defoverridable seed_default_props: 3,
                     render_header: 1,
                     render_top_bar_actions: 1
    end
  end

  # ─── shell_render/1 — composes the full editor layout ──────────────────

  @doc false
  def shell_render(assigns) do
    consumer = assigns.__consumer__
    page_settings = assigns.__page_settings__

    # render_header / render_top_bar_actions get the FULL assigns map so
    # consumer overrides can read any socket assign (page, brand, etc.)
    # they set up in `load/3`. We pre-render here (outside the shell slot
    # body) so closure capture of the outer assigns is unambiguous.
    header_rendered = consumer.render_header(assigns)

    actions_rendered =
      consumer.render_top_bar_actions(%{
        preview_viewport: assigns[:preview_viewport] || :desktop
      })

    assigns =
      assigns
      |> assign(:consumer, consumer)
      |> assign(:page_settings, page_settings)
      |> assign(:header_rendered, header_rendered)
      |> assign(:actions_rendered, actions_rendered)
      |> assign(:preview_viewport, assigns[:preview_viewport] || :desktop)

    # Inside `<Athanor.Editor.shell>` slot bodies, `@<key>` resolves to
    # the outer assigns (shell_render's). slot_ctx names — `:page_title`,
    # `:selected_component_id`, `:viewport` — are exposed via `:let={ctx}`
    # only; without :let, slot bodies read outer assigns directly.
    ~H"""
    <Athanor.Editor.shell
      page_title={Map.get(assigns, :page_title)}
      selected_component_id={@selected_component_id}
      viewport={@preview_viewport}
      show_components_panel={@show_components_panel}
    >
      <:header>
        <div class="flex items-center justify-between w-full">
          {@header_rendered}
          {@actions_rendered}
        </div>
      </:header>

      <:sidebar_left>
        <Athanor.Editor.components_panel
          ctx={@ctx}
          page_settings_component={@page_settings}
          metadata={@metadata}
        />
      </:sidebar_left>

      <Athanor.Editor.canvas
        content={@content}
        ctx={@ctx}
        selected_component_id={@selected_component_id}
        viewport={@preview_viewport}
      />

      <:sidebar_right>
        <Athanor.Editor.config_panel
          selected_component_id={@selected_component_id}
          content={@content}
          ctx={@ctx}
        />
      </:sidebar_right>

      <:modals>
        <Athanor.Editor.zone_picker_modal column_picker={@column_picker} />
      </:modals>
    </Athanor.Editor.shell>
    """
  end

  # ─── default header + actions ──────────────────────────────────────────

  @doc "Default barebones header — back button + optional page title."
  def default_render_header(assigns) do
    assigns = Map.put_new(assigns, :page_title, nil)

    ~H"""
    <div class="flex items-center gap-2 px-4 py-3">
      <button onclick="history.back()" class="btn btn-sm btn-ghost">
        <i class="fa-solid fa-arrow-left"></i> Back
      </button>
      <span :if={@page_title} class="font-semibold">{@page_title}</span>
    </div>
    """
  end

  @doc "Default top-bar actions — viewport switcher + Save."
  def default_render_top_bar_actions(assigns) do
    assigns = Map.put_new(assigns, :preview_viewport, :desktop)

    ~H"""
    <div class="flex items-center gap-3 px-4">
      <div
        role="radiogroup"
        aria-label="Viewport"
        class="inline-flex items-center gap-0.5 bg-base-200 rounded-lg p-0.5"
      >
        <button
          :for={vp <- [:desktop, :tablet, :mobile]}
          type="button"
          role="radio"
          aria-checked={if @preview_viewport == vp, do: "true", else: "false"}
          aria-label={"Switch to #{Atom.to_string(vp)} viewport"}
          data-testid={"viewport-#{Atom.to_string(vp)}"}
          phx-click="set_viewport"
          phx-value-viewport={Atom.to_string(vp)}
          class={[
            "h-8 w-8 inline-flex items-center justify-center rounded-md cursor-pointer transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40",
            if(@preview_viewport == vp,
              do: "bg-base-100 text-primary shadow-sm",
              else: "text-base-content/60 hover:text-base-content"
            )
          ]}
        >
          <i class={["fa-solid", viewport_icon(vp), "text-sm"]} aria-hidden="true" />
        </button>
      </div>
      <button
        type="button"
        phx-click="save"
        class="btn btn-sm btn-primary gap-2 cursor-pointer"
      >
        <i class="fa-solid fa-floppy-disk text-xs" aria-hidden="true"></i> Save
      </button>
    </div>
    """
  end

  defp viewport_icon(:desktop), do: "fa-desktop"
  defp viewport_icon(:tablet), do: "fa-tablet-screen-button"
  defp viewport_icon(:mobile), do: "fa-mobile-screen"

  # ─── mount/4 ───────────────────────────────────────────────────────────

  @doc false
  def mount(consumer_module, params, session, socket) do
    opts = consumer_opts(consumer_module)
    warn_if_registered(Map.get(opts, :page_settings_component))

    case consumer_module.load(params, session, socket) do
      {:ok, load_result} ->
        finalize_mount(socket, load_result, opts, %{})

      {:ok, load_result, socket_assigns} when is_map(socket_assigns) ->
        finalize_mount(socket, load_result, opts, socket_assigns)

      {:error, _} = err ->
        err
    end
  end

  defp finalize_mount(socket, load_result, opts, socket_assigns) do
    state = build_initial_state(load_result, opts)

    socket =
      socket
      |> assign_extras(socket_assigns)
      |> assign_state(state)

    case Map.get(opts, :layout) do
      nil -> {:ok, socket}
      layout -> {:ok, socket, layout: layout}
    end
  end

  defp assign_extras(socket, extras) when extras == %{}, do: socket

  defp assign_extras(socket, extras) when is_map(extras) do
    Enum.reduce(extras, socket, fn {key, value}, acc ->
      Phoenix.Component.assign(acc, key, value)
    end)
  end

  defp consumer_opts(consumer_module) do
    if function_exported?(consumer_module, :athanor_editor_opts, 0) do
      Map.new(consumer_module.athanor_editor_opts())
    else
      %{}
    end
  end

  @doc """
  Emit a one-time warning if `page_settings_component` is also listed in
  `config :athanor, :components`. A page-settings module shouldn't show
  up in the palette — registering it would pollute the components panel
  with a "Page Settings" entry that, if dropped onto the canvas, would
  not render anything (it has no `render/3`).

  Called from `mount/4`; also publicly callable for tests.
  """
  def warn_if_registered(nil), do: :ok

  def warn_if_registered(module) when is_atom(module) do
    if module in Athanor.Registry.all() do
      Logger.warning(fn ->
        "Athanor.Editor: page_settings_component (#{inspect(module)}) is also " <>
          "registered in Athanor.Registry. Remove it from `config :athanor, " <>
          ":components` — page-settings components should not appear in the " <>
          "components palette."
      end)
    end

    :ok
  end

  # ─── handle_event/4 ────────────────────────────────────────────────────

  @doc false
  def handle_event(consumer_module, event, params, socket)

  def handle_event(_consumer, "select_component", %{"id" => id}, socket) do
    {:noreply, update_state(socket, &do_select_component(&1, id))}
  end

  def handle_event(_consumer, "close_config", _params, socket) do
    {:noreply, update_state(socket, &do_close_config/1)}
  end

  def handle_event(_consumer, "set_viewport", %{"viewport" => vp}, socket) do
    {:noreply, update_state(socket, &do_set_viewport(&1, vp))}
  end

  def handle_event(_consumer, "toggle_components_panel", _, socket) do
    {:noreply, update_state(socket, &do_toggle_components_panel/1)}
  end

  def handle_event(_consumer, "show_zone_picker", params, socket) do
    parent_id = params["parent-id"] || params["parent_id"]
    zone_name = params["zone-name"] || params["zone_name"]
    {:noreply, update_state(socket, &do_show_zone_picker(&1, parent_id, zone_name))}
  end

  def handle_event(_consumer, "cancel_zone_picker", _, socket) do
    {:noreply, update_state(socket, &do_cancel_zone_picker/1)}
  end

  def handle_event(consumer, "add_component", %{"type" => type} = params, socket) do
    {:noreply, update_state(socket, &do_add_component(&1, consumer, type, params, socket))}
  end

  def handle_event(
        consumer,
        "add_component_to_zone",
        %{"parent_id" => pid, "zone_name" => zn, "type" => type},
        socket
      ) do
    {:noreply,
     update_state(socket, &do_add_component_to_zone(&1, consumer, pid, zn, type, socket))}
  end

  def handle_event(_consumer, "remove_component", %{"id" => id}, socket) do
    {:noreply, update_state(socket, &do_remove_component(&1, id))}
  end

  def handle_event(_consumer, "move_component", %{"id" => id, "direction" => dir}, socket) do
    {:noreply, update_state(socket, &do_move_component(&1, id, dir))}
  end

  def handle_event(consumer, "athanor:dnd_drop", params, socket) do
    {:noreply, update_state(socket, &do_dnd_drop(&1, consumer, params, socket))}
  end

  def handle_event(consumer, "save", _params, socket) do
    {:noreply, do_save(consumer, socket)}
  end

  def handle_event(_consumer, _event, _params, socket) do
    {:noreply, socket}
  end

  # ─── handle_info/3 ─────────────────────────────────────────────────────
  #
  # DESIGN: page-settings vs content routing in ONE handler.
  #
  # `AutoEditorForm` fires `{:update_component_props, component_id, new_props}`
  # for ANY editable surface — both regular component config (right
  # sidebar) and page-settings (left sidebar). We route by `component_id`:
  #
  #   • "page-settings" (literal id we assign to the page-settings form
  #     LC) → write into @metadata
  #   • anything else → walk the content tree via Tree.update_props/3
  #     and merge into @content
  #
  # This single-channel routing is the trick that lets page-settings
  # reuse the same `Athanor.Component` contract and `AutoEditorForm`
  # machinery components use, with zero new abstraction. The price is
  # the literal "page-settings" string being a reserved component_id —
  # documented in the user-facing `Athanor.Editor` docstring.

  @doc false
  def handle_info(_consumer, {:update_component_props, "page-settings", new_metadata}, socket) do
    {:noreply, update_state(socket, fn state -> %{state | metadata: new_metadata} end)}
  end

  def handle_info(_consumer, {:update_component_props, component_id, new_props}, socket) do
    state = current_state(socket)

    case Tree.update_props(state.content, component_id, fn _ -> new_props end) do
      {:ok, new_content} ->
        {:noreply, update_state(socket, fn s -> %{s | content: new_content} end)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_info(_consumer, _msg, socket), do: {:noreply, socket}

  # ─── internal state transformations (unit-tested directly) ─────────────

  @doc false
  def build_initial_state(load_result, opts) do
    ctx_extras = %{
      edit_mode?: true,
      add_component_callback: fn _zone ->
        Phoenix.LiveView.JS.push("show_zone_picker")
      end,
      select_component_callback: fn _id ->
        Phoenix.LiveView.JS.push("select_component")
      end
    }

    ctx_args =
      load_result
      |> Map.get(:ctx_assigns, %{})
      |> Map.merge(ctx_extras)
      |> Map.to_list()

    ctx = Ctx.new(ctx_args)

    %State{
      content: Map.get(load_result, :content, %{"content" => []}),
      metadata: Map.get(load_result, :metadata, %{}),
      selected_component_id: nil,
      column_picker: nil,
      preview_viewport: Map.get(opts, :preview_viewport, :desktop),
      show_components_panel: Map.get(opts, :show_components_panel, true),
      ctx: ctx
    }
  end

  @doc false
  def do_select_component(%State{} = state, id), do: %{state | selected_component_id: id}

  @doc false
  def do_close_config(%State{} = state), do: %{state | selected_component_id: nil}

  @doc false
  def do_set_viewport(%State{} = state, vp) when vp in @viewport_strings,
    do: %{state | preview_viewport: String.to_existing_atom(vp)}

  def do_set_viewport(%State{} = state, vp) when vp in @viewport_values,
    do: %{state | preview_viewport: vp}

  def do_set_viewport(%State{} = state, _), do: state

  @doc false
  def do_toggle_components_panel(%State{} = state),
    do: %{state | show_components_panel: not state.show_components_panel}

  @doc false
  def do_show_zone_picker(%State{} = state, parent_id, zone_name),
    do: %{state | column_picker: {parent_id, zone_name}}

  @doc false
  def do_cancel_zone_picker(%State{} = state), do: %{state | column_picker: nil}

  @doc false
  def do_add_component(%State{} = state, consumer_module, type, _params, socket) do
    new_component = build_component(consumer_module, type, socket)

    case Tree.insert(state.content, :root, new_component) do
      {:ok, updated} ->
        %{state | content: updated, selected_component_id: new_component["id"]}

      {:error, _} ->
        state
    end
  end

  @doc false
  def do_add_component_to_zone(
        %State{} = state,
        consumer_module,
        parent_id,
        zone_name,
        type,
        socket
      ) do
    new_component = build_component(consumer_module, type, socket)

    case Tree.insert(state.content, {parent_id, zone_name}, new_component) do
      {:ok, updated} ->
        %{
          state
          | content: updated,
            column_picker: nil,
            selected_component_id: new_component["id"]
        }

      {:error, _} ->
        %{state | column_picker: nil}
    end
  end

  @doc false
  def do_remove_component(%State{} = state, id) do
    # Tree.remove/2 is total — always returns `{:ok, content}`. The
    # branch was kept defensively in early drafts but dialyzer flags it
    # as dead.
    {:ok, updated} = Tree.remove(state.content, id)

    %{
      state
      | content: updated,
        selected_component_id:
          if(state.selected_component_id == id, do: nil, else: state.selected_component_id)
    }
  end

  @doc false
  def do_dnd_drop(%State{} = state, consumer_module, params, socket) do
    parent_id = params["target_parent_id"]
    zone_name = params["target_zone"]
    index = parse_index(params["target_index"])
    target = drop_target(parent_id, zone_name)

    case params["source"] do
      "palette" ->
        type = params["type"]
        new_component = build_component(consumer_module, type, socket)

        case Tree.insert(state.content, target, new_component, at: {:index, index}) do
          {:ok, updated} ->
            %{state | content: updated, selected_component_id: new_component["id"]}

          {:error, _} ->
            state
        end

      "tree" ->
        node_id = params["node_id"]

        case Tree.move_to(state.content, node_id, target, at: {:index, index}) do
          {:ok, updated} ->
            %{state | content: updated}

          {:error, _} ->
            state
        end

      _ ->
        state
    end
  end

  defp drop_target("root", _), do: :root
  defp drop_target(nil, _), do: :root

  defp drop_target(parent_id, zone) when is_binary(parent_id) and is_binary(zone),
    do: {parent_id, zone}

  defp parse_index(n) when is_integer(n) and n >= 0, do: n

  defp parse_index(n) when is_binary(n) do
    case Integer.parse(n) do
      {i, _} when i >= 0 -> i
      _ -> 0
    end
  end

  defp parse_index(_), do: 0

  @doc false
  def do_move_component(%State{} = state, id, direction) do
    dir = if direction == "up", do: :up, else: :down

    case Tree.move(state.content, id, dir) do
      {:ok, updated} -> %{state | content: updated}
      _ -> state
    end
  end

  # ─── save ─────────────────────────────────────────────────────────────

  defp do_save(consumer_module, socket) do
    state = current_state(socket)

    case consumer_module.save(socket, %{content: state.content, metadata: state.metadata}) do
      {:ok, _} ->
        Phoenix.LiveView.put_flash(socket, :info, "Saved")

      {:error, reason} ->
        Phoenix.LiveView.put_flash(socket, :error, "Save failed: #{inspect(reason)}")
    end
  end

  # ─── socket helpers ────────────────────────────────────────────────────

  defp current_state(socket) do
    %State{
      content: socket.assigns[:content] || %{"content" => []},
      metadata: socket.assigns[:metadata] || %{},
      selected_component_id: socket.assigns[:selected_component_id],
      column_picker: socket.assigns[:column_picker],
      preview_viewport: socket.assigns[:preview_viewport] || :desktop,
      show_components_panel: socket.assigns[:show_components_panel] != false,
      ctx: socket.assigns[:ctx]
    }
  end

  defp update_state(socket, fun) do
    state = current_state(socket)
    new_state = fun.(state)
    assign_state(socket, new_state)
  end

  defp assign_state(socket, %State{} = state) do
    socket
    |> Phoenix.Component.assign(:content, state.content)
    |> Phoenix.Component.assign(:metadata, state.metadata)
    |> Phoenix.Component.assign(:selected_component_id, state.selected_component_id)
    |> Phoenix.Component.assign(:column_picker, state.column_picker)
    |> Phoenix.Component.assign(:preview_viewport, state.preview_viewport)
    |> Phoenix.Component.assign(:show_components_panel, state.show_components_panel)
    |> Phoenix.Component.assign(:ctx, state.ctx)
  end

  # ─── build_component ───────────────────────────────────────────────────

  defp build_component(consumer_module, type, socket) do
    merged_props =
      case Athanor.Registry.lookup(type) do
        nil ->
          %{}

        mod ->
          if function_exported?(mod, :default_props, 0), do: mod.default_props(), else: %{}
      end

    component = %{
      "id" => generate_id(),
      "type" => type,
      "props" => merged_props
    }

    consumer_module.seed_default_props(component, type, socket)
  end

  defp generate_id do
    System.unique_integer([:positive])
    |> Integer.to_string()
    |> then(&("node_" <> &1))
  end
end
