defmodule Athanor.AutoEditorForm do
  @moduledoc """
  Auto-generated editor form for components that declare `fields/0`.

  Mounted by `Athanor.Renderer` when a component's `fields/0` is
  non-empty. Wraps `Athanor.Components.EditorFormShell` with two tabs
  (Component + Formatting). The Component tab is filled by
  `Athanor.Fields.render/1`; the Formatting tab is the shared formatting
  surface.

  Owns the LC state every editor form needs:
  - `active_tab`        — "component" | "formatting"
  - `open_sections`     — MapSet of expanded formatting collapsibles
  - `formatting_form`   — Phoenix form for the formatting tab
  - `props`             — current component prop map

  Single replacement for the hand-written `*.EditorForm` LCs of
  Step 4. After Phase 5-7, `Heading.EditorForm`, `Button.EditorForm`,
  and `Divider.EditorForm` are deleted; their components declare
  `fields/0` and this LC handles them all.
  """

  use Phoenix.LiveComponent

  alias Athanor.Components.EditorFormShell
  alias Athanor.Components.Formatting.EditorForm, as: FormattingEditorForm

  # Custom field on_change → routed back into our own update/2.
  @impl true
  def update(%{action: {:custom_field_changed, key, value}}, socket) do
    new_props = Map.put(socket.assigns.props, key, value)
    send(self(), {:update_component_props, socket.assigns.component_id, new_props})
    {:ok, Phoenix.Component.assign(socket, :props, new_props)}
  end

  def update(assigns, socket) do
    props = assigns[:props] || %{}
    formatting_form = FormattingEditorForm.build_form(props["formatting"] || %{})

    {:ok,
     socket
     |> Phoenix.Component.assign(assigns)
     |> Phoenix.Component.assign_new(:active_tab, fn -> "component" end)
     |> Phoenix.Component.assign_new(:open_sections, fn ->
       FormattingEditorForm.default_open_sections()
     end)
     |> Phoenix.Component.assign(:formatting_form, formatting_form)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, Phoenix.Component.assign(socket, :active_tab, tab)}
  end

  def handle_event("toggle_section", %{"section" => section}, socket) do
    next = FormattingEditorForm.toggle_section(socket.assigns.open_sections, section)
    {:noreply, Phoenix.Component.assign(socket, :open_sections, next)}
  end

  # Formatting tab form fires with %{"formatting" => fmt_params}
  def handle_event("update_props", %{"formatting" => formatting_params}, socket) do
    new_props =
      Map.put(
        socket.assigns.props,
        "formatting",
        FormattingEditorForm.coerce_params(formatting_params)
      )

    send(self(), {:update_component_props, socket.assigns.component_id, new_props})
    {:noreply, socket}
  end

  # Component tab form fires with flat field params (per `name=` attr).
  def handle_event("update_props", params, socket) when is_map(params) do
    fields = field_index(socket.assigns.component_module)

    new_props =
      params
      |> Map.take(Map.keys(fields))
      |> Enum.reduce(socket.assigns.props, fn {key, raw}, acc ->
        Map.put(acc, key, coerce(raw, fields[key]))
      end)

    send(self(), {:update_component_props, socket.assigns.component_id, new_props})
    {:noreply, socket}
  end

  defp field_index(module) do
    module.fields()
    |> Enum.map(fn {key, type, _opts} -> {key, type} end)
    |> Map.new()
  end

  @doc false
  def coerce(value, type)

  def coerce(value, :number) when is_integer(value), do: value

  def coerce(value, :number) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      _ -> 0
    end
  end

  def coerce(value, :number), do: value

  def coerce(value, :checkbox) when is_boolean(value), do: value
  def coerce("true", :checkbox), do: true
  def coerce("false", :checkbox), do: false
  def coerce(value, :checkbox), do: !!value

  def coerce(value, _type), do: value

  @impl true
  def render(assigns) do
    component_id = assigns.id

    on_custom_change_fn = fn key, value ->
      send_update(__MODULE__,
        id: component_id,
        action: {:custom_field_changed, key, value}
      )
    end

    assigns = Phoenix.Component.assign(assigns, :on_custom_change, on_custom_change_fn)

    ~H"""
    <div data-testid="athanor-auto-editor-form">
      <EditorFormShell.shell
        active_tab={@active_tab}
        myself={@myself}
        formatting_form={@formatting_form}
        open_sections={@open_sections}
      >
        <:component>
          <Athanor.Fields.render
            module={@component_module}
            props={@props}
            ctx={@ctx}
            myself={@myself}
            on_custom_change={@on_custom_change}
          />
        </:component>
      </EditorFormShell.shell>
    </div>
    """
  end
end
