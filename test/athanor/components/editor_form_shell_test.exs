defmodule Athanor.Components.EditorFormShellTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Components.EditorFormShell
  alias Athanor.Components.Formatting.EditorForm, as: FormattingEditorForm

  defp render_shell(active_tab) do
    assigns = %{
      active_tab: active_tab,
      myself: nil,
      formatting_form: FormattingEditorForm.build_form(%{}),
      open_sections: FormattingEditorForm.default_open_sections()
    }

    render_component(
      fn assigns ->
        ~H"""
        <EditorFormShell.shell
          active_tab={@active_tab}
          myself={@myself}
          formatting_form={@formatting_form}
          open_sections={@open_sections}
        >
          <:component>
            <div data-testid="component-slot-marker">component-slot</div>
          </:component>
        </EditorFormShell.shell>
        """
      end,
      assigns
    )
  end

  describe "shell/1" do
    test "renders both Component and Formatting tab labels" do
      html = render_shell("component")

      assert html =~ "Component"
      assert html =~ "Formatting"
    end

    test "active_tab='component' shows the component slot, not the formatting form" do
      html = render_shell("component")

      assert html =~ "component-slot-marker"
      refute html =~ "athanor-formatting-editor-form"
    end

    test "active_tab='formatting' shows the formatting form, not the component slot" do
      html = render_shell("formatting")

      assert html =~ "athanor-formatting-editor-form"
      refute html =~ "component-slot-marker"
    end

    test "active tab class applied to the right anchor" do
      html_comp = render_shell("component")
      assert html_comp =~ ~r/tab tab-active[^>]*>\s*Component/

      html_fmt = render_shell("formatting")
      assert html_fmt =~ ~r/tab tab-active[^>]*>\s*Formatting/
    end

    test "data-testid present for selectors" do
      html = render_shell("component")
      assert html =~ ~s(data-testid="athanor-editor-form-shell")
    end
  end
end
