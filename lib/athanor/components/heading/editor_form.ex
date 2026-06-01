defmodule Athanor.Components.Heading.EditorForm do
  @moduledoc """
  Editor form for `Athanor.Components.Heading`. Tabbed UI via
  `Athanor.Components.EditorFormShell`. Component tab edits text + level;
  Formatting tab is the shared 14-field surface.

  On any phx-change, the component sends a wholesale prop replacement
  back to the host LV via `{:update_component_props, component_id, new_props}`.
  """

  use Phoenix.LiveComponent

  alias Athanor.Components.EditorFormShell
  alias Athanor.Components.Formatting.EditorForm, as: FormattingEditorForm

  @impl true
  def update(assigns, socket) do
    props = assigns[:props] || %{}

    component_form =
      Phoenix.Component.to_form(%{
        "text" => props["text"] || "",
        "level" => to_string(props["level"] || 2)
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

  def handle_event("update_props", %{"text" => text, "level" => level}, socket) do
    new_props =
      socket.assigns.props
      |> Map.put("text", text)
      |> Map.put("level", parse_int(level, 2))

    send(self(), {:update_component_props, socket.assigns.component_id, new_props})
    {:noreply, socket}
  end

  defp parse_int(n, _default) when is_integer(n), do: n

  defp parse_int(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      _ -> default
    end
  end

  defp parse_int(_, default), do: default

  @impl true
  def render(assigns) do
    ~H"""
    <div data-testid="athanor-heading-editor-form">
      <EditorFormShell.shell
        active_tab={@active_tab}
        myself={@myself}
        formatting_form={@formatting_form}
        open_sections={@open_sections}
      >
        <:component>
          <.form for={@component_form} phx-change="update_props" phx-target={@myself}>
            <div class="flex flex-col gap-2">
              <label class="text-xs font-semibold">Text</label>
              <input
                type="text"
                name="text"
                value={@component_form[:text].value}
                class="input input-bordered input-sm"
                phx-debounce="300"
              />

              <label class="text-xs font-semibold mt-2">Level</label>
              <select name="level" class="select select-bordered select-sm">
                <option
                  :for={n <- 1..6}
                  value={to_string(n)}
                  selected={@component_form[:level].value == to_string(n)}
                >
                  H{n}
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
