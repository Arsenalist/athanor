defmodule Athanor.Components.Button.EditorForm do
  @moduledoc """
  Editor form for `Athanor.Components.Button`. Tabbed UI via
  `Athanor.Components.EditorFormShell`. Component tab edits label/href/
  variant/size/target/rel; Formatting tab is the shared 14-field surface.
  """

  use Phoenix.LiveComponent

  alias Athanor.Components.EditorFormShell
  alias Athanor.Components.Formatting.EditorForm, as: FormattingEditorForm

  @component_keys ["label", "href", "variant", "size", "target", "rel"]

  @impl true
  def update(assigns, socket) do
    props = assigns[:props] || %{}

    component_form =
      Phoenix.Component.to_form(%{
        "label" => props["label"] || "",
        "href" => props["href"] || "",
        "variant" => props["variant"] || "primary",
        "size" => props["size"] || "md",
        "target" => props["target"] || "_self",
        "rel" => props["rel"] || "noopener"
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

  def handle_event("update_props", params, socket) do
    new_props = Map.merge(socket.assigns.props, Map.take(params, @component_keys))
    send(self(), {:update_component_props, socket.assigns.component_id, new_props})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-testid="athanor-button-editor-form">
      <EditorFormShell.shell
        active_tab={@active_tab}
        myself={@myself}
        formatting_form={@formatting_form}
        open_sections={@open_sections}
      >
        <:component>
          <.form for={@component_form} phx-change="update_props" phx-target={@myself}>
            <div class="flex flex-col gap-2">
              <label class="text-xs font-semibold">Label</label>
              <input
                type="text"
                name="label"
                value={@component_form[:label].value}
                class="input input-bordered input-sm"
                phx-debounce="300"
              />

              <label class="text-xs font-semibold mt-2">URL</label>
              <input
                type="text"
                name="href"
                value={@component_form[:href].value}
                class="input input-bordered input-sm"
                phx-debounce="300"
              />

              <label class="text-xs font-semibold mt-2">Variant</label>
              <select name="variant" class="select select-bordered select-sm">
                <option
                  :for={v <- ["primary", "secondary", "ghost"]}
                  value={v}
                  selected={@component_form[:variant].value == v}
                >
                  {String.capitalize(v)}
                </option>
              </select>

              <label class="text-xs font-semibold mt-2">Size</label>
              <select name="size" class="select select-bordered select-sm">
                <option
                  :for={s <- ["sm", "md", "lg"]}
                  value={s}
                  selected={@component_form[:size].value == s}
                >
                  {String.upcase(s)}
                </option>
              </select>

              <label class="text-xs font-semibold mt-2">Target</label>
              <select name="target" class="select select-bordered select-sm">
                <option
                  :for={t <- ["_self", "_blank", "_parent", "_top"]}
                  value={t}
                  selected={@component_form[:target].value == t}
                >
                  {t}
                </option>
              </select>

              <label class="text-xs font-semibold mt-2">Rel</label>
              <input
                type="text"
                name="rel"
                value={@component_form[:rel].value}
                class="input input-bordered input-sm"
                phx-debounce="300"
              />
            </div>
          </.form>
        </:component>
      </EditorFormShell.shell>
    </div>
    """
  end
end
