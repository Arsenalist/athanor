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

  import Athanor.Test.RegistryHelpers
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
    put_test_registry([WithFields, NoConfig])
    :ok
  end

  defp render_panel(selected_id, content) do
    assigns = %{
      selected_component_id: selected_id,
      content: content,
      ctx: Ctx.new(registry: :test, edit_mode?: true)
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

  describe "header move controls" do
    @three %{
      "content" => [
        %{"id" => "a", "type" => "nc", "props" => %{}},
        %{"id" => "b", "type" => "nc", "props" => %{}},
        %{"id" => "c", "type" => "nc", "props" => %{}}
      ]
    }

    test "middle node renders up/down/top/bottom bound to move_component" do
      html = render_panel("b", @three)

      for dir <- ~w(up down top bottom) do
        assert html =~ ~s(data-testid="component-config-move-#{dir}")
        assert html =~ ~s(phx-value-direction="#{dir}")
      end

      assert html =~ ~s(phx-click="move_component")
    end

    test "first node hides top/up; last node hides down/bottom" do
      first = render_panel("a", @three)
      refute first =~ ~s(component-config-move-top")
      refute first =~ ~s(component-config-move-up")
      assert first =~ ~s(component-config-move-down")
      assert first =~ ~s(component-config-move-bottom")

      last = render_panel("c", @three)
      assert last =~ ~s(component-config-move-top")
      assert last =~ ~s(component-config-move-up")
      refute last =~ ~s(component-config-move-down")
      refute last =~ ~s(component-config-move-bottom")
    end

    test "sole node renders no move controls" do
      html = render_panel("n1", %{"content" => [%{"id" => "n1", "type" => "nc", "props" => %{}}]})
      refute html =~ "component-config-move-"
    end
  end

  describe "selected component has no fields and no editor_form" do
    test "still mounts AutoEditorForm (Formatting tab) with a no-config placeholder" do
      content = %{"content" => [%{"id" => "n1", "type" => "nc", "props" => %{}}]}
      html = render_panel("n1", content)
      assert html =~ ~s(data-testid="athanor-auto-editor-form")
      assert html =~ ~s(data-testid="component-no-config")
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
