defmodule Athanor.Components.EditorFormShell do
  @moduledoc """
  Tabs wrapper used by every Athanor primitive's editor form LC. Renders
  a two-tab UI: "Component" (the component-specific form, supplied via the
  `:component` slot) and "Formatting" (the shared formatting controls).

  Usage from a LiveComponent's render/1:

      ~H"\""
      <Athanor.Components.EditorFormShell.shell
        active_tab={@active_tab}
        myself={@myself}
        formatting_form={@formatting_form}>
        <:component>
          <!-- component-specific form here -->
        </:component>
      </Athanor.Components.EditorFormShell.shell>
      "\""
  """

  use Phoenix.Component

  alias Athanor.Components.Formatting.EditorForm, as: FormattingEditorForm

  attr :active_tab, :string, default: "component"
  attr :myself, :any, required: true
  attr :formatting_form, :any, required: true
  attr :open_sections, :any, required: true
  slot :component, required: true

  def shell(assigns) do
    ~H"""
    <div data-testid="athanor-editor-form-shell">
      <div role="tablist" class="tabs tabs-boxed">
        <a
          role="tab"
          class={"tab " <> if @active_tab == "component", do: "tab-active", else: ""}
          phx-click="switch_tab"
          phx-value-tab="component"
          phx-target={@myself}
        >
          Component
        </a>
        <a
          role="tab"
          class={"tab " <> if @active_tab == "formatting", do: "tab-active", else: ""}
          phx-click="switch_tab"
          phx-value-tab="formatting"
          phx-target={@myself}
        >
          Formatting
        </a>
      </div>

      <div :if={@active_tab == "component"} class="mt-3">
        {render_slot(@component)}
      </div>

      <div :if={@active_tab == "formatting"} class="mt-3">
        <FormattingEditorForm.editor_form
          form={@formatting_form}
          myself={@myself}
          open_sections={@open_sections}
        />
      </div>
    </div>
    """
  end
end
