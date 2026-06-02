defmodule Athanor.Editor.ConfigPanelTest do
  @moduledoc """
  Tests for `Athanor.Editor.config_panel/1` — the right-sidebar
  content. Renders the selected component's config form via
  `Athanor.AutoEditorForm` when the selected component has `fields/0`;
  renders `:none` placeholder when the component has neither
  `fields/0` nor `editor_form/0`; renders nothing when no component
  is selected.
  """

  use ExUnit.Case, async: false
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Ctx
  alias Athanor.Editor

  defmodule WithFields do
    use Athanor.Component
    def metadata, do: %{type: "wf", label: "WF"}
    def fields, do: [{"title", :text, label: "Title"}]
  end

  defmodule NoConfig do
    use Athanor.Component
    def metadata, do: %{type: "nc", label: "NC"}
  end

  setup do
    Application.put_env(:athanor, :components, [WithFields, NoConfig])
    on_exit(fn -> Application.put_env(:athanor, :components, []) end)
    :ok
  end

  defp render_panel(selected_id, content) do
    assigns = %{
      selected_component_id: selected_id,
      content: content,
      ctx: Ctx.new(edit_mode?: true)
    }

    render_component(
      fn assigns ->
        ~H"""
        <Editor.config_panel
          selected_component_id={@selected_component_id}
          content={@content}
          ctx={@ctx}
        />
        """
      end,
      assigns
    )
  end

  describe "nothing selected" do
    test "renders nothing visible (empty wrapper at most)" do
      html = render_panel(nil, %{"content" => []})
      refute html =~ ~s(data-testid="athanor-auto-editor-form")
      refute html =~ ~s(data-testid="component-no-config")
    end
  end

  describe "selected component has fields/0" do
    test "mounts AutoEditorForm" do
      content = %{"content" => [%{"id" => "n1", "type" => "wf", "props" => %{"title" => "T"}}]}
      html = render_panel("n1", content)
      assert html =~ ~s(data-testid="athanor-auto-editor-form")
    end
  end

  describe "selected component has no fields and no editor_form" do
    test "renders the no-config placeholder" do
      content = %{"content" => [%{"id" => "n1", "type" => "nc", "props" => %{}}]}
      html = render_panel("n1", content)
      assert html =~ ~s(data-testid="component-no-config")
      refute html =~ ~s(data-testid="athanor-auto-editor-form")
    end
  end

  describe "selected id not found in tree" do
    test "renders nothing" do
      content = %{"content" => []}
      html = render_panel("ghost", content)
      refute html =~ ~s(data-testid="athanor-auto-editor-form")
      refute html =~ ~s(data-testid="component-no-config")
    end
  end
end
