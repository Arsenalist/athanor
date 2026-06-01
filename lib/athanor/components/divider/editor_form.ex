defmodule Athanor.Components.Divider.EditorForm do
  @moduledoc """
  Editor form for `Athanor.Components.Divider`. Tabbed UI via
  `Athanor.Components.EditorFormShell`.
  """

  use Phoenix.LiveComponent

  alias Athanor.Components.EditorFormShell
  alias Athanor.Components.Formatting.EditorForm, as: FormattingEditorForm

  @impl true
  def update(assigns, socket) do
    props = assigns[:props] || %{}

    component_form =
      Phoenix.Component.to_form(%{
        "thickness" => to_string(props["thickness"] || 1),
        "color" => props["color"] || "#e5e7eb",
        "margin_y" => props["margin_y"] || "md"
      })

    formatting_form = FormattingEditorForm.build_form(props["formatting"] || %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:active_tab, fn -> "component" end)
     |> assign_new(:open_sections, fn -> FormattingEditorForm.default_open_sections() end)
     |> assign(:component_form, component_form)
     |> assign(:formatting_form, formatting_form)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("toggle_section", %{"section" => section}, socket) do
    {:noreply,
     assign(socket, :open_sections, FormattingEditorForm.toggle_section(socket.assigns.open_sections, section))}
  end

  def handle_event("update_props", %{"formatting" => formatting_params}, socket) do
    new_props =
      socket.assigns.props
      |> Map.put("formatting", FormattingEditorForm.coerce_params(formatting_params))

    send(self(), {:update_component_props, socket.assigns.component_id, new_props})
    {:noreply, socket}
  end

  def handle_event("update_props", %{"thickness" => t, "color" => c, "margin_y" => m}, socket) do
    thickness =
      case Integer.parse(t) do
        {n, _} -> n
        _ -> 1
      end

    new_props =
      socket.assigns.props
      |> Map.put("thickness", thickness)
      |> Map.put("color", c)
      |> Map.put("margin_y", m)

    send(self(), {:update_component_props, socket.assigns.component_id, new_props})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-testid="athanor-divider-editor-form">
      <EditorFormShell.shell
        active_tab={@active_tab}
        myself={@myself}
        formatting_form={@formatting_form}
        open_sections={@open_sections}
      >
        <:component>
          <.form for={@component_form} phx-change="update_props" phx-target={@myself}>
            <div class="flex flex-col gap-2">
              <label class="text-xs font-semibold">Thickness (px)</label>
              <input
                type="number"
                name="thickness"
                value={@component_form[:thickness].value}
                min="0"
                max="16"
                class="input input-bordered input-sm"
                phx-debounce="300"
              />

              <label class="text-xs font-semibold mt-2">Color</label>
              <input
                type="color"
                name="color"
                value={@component_form[:color].value}
                class="input input-bordered input-sm h-10"
              />

              <label class="text-xs font-semibold mt-2">Vertical margin</label>
              <select name="margin_y" class="select select-bordered select-sm">
                <option
                  :for={m <- ["sm", "md", "lg"]}
                  value={m}
                  selected={@component_form[:margin_y].value == m}
                >
                  {String.upcase(m)}
                </option>
              </select>
            </div>
          </.form>
        </:component>
      </EditorFormShell.shell>
    </div>
    """
  end
end
