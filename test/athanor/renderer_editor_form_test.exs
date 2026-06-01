defmodule Athanor.RendererEditorFormTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Athanor.Ctx
  alias Athanor.Test.FakeComponents.{EditorFormFake, NoEditorFormFake}

  setup do
    original = Application.get_env(:athanor, :components)

    on_exit(fn ->
      if original do
        Application.put_env(:athanor, :components, original)
      else
        Application.delete_env(:athanor, :components)
      end
    end)

    :ok
  end

  defp set_components(modules), do: Application.put_env(:athanor, :components, modules)

  defp node_for(type, id), do: %{"id" => id, "type" => type, "props" => %{}}

  describe "editor_form dispatch" do
    test "edit_mode + show_config + non-nil editor_form → mounts the editor_form LC" do
      set_components([EditorFormFake])

      tree = %{"metadata" => %{}, "content" => [node_for("fake_editor_form", "n1")]}

      html =
        render_component(&Athanor.Renderer.tree/1,
          tree: tree,
          ctx: Ctx.new(),
          edit_mode: true,
          show_config: true
        )

      assert html =~ ~s(data-editor-form-fake-lc="n1")
      refute html =~ "preview"
    end

    test "edit_mode + show_config=false → calls render/3 (preview)" do
      set_components([EditorFormFake])
      tree = %{"metadata" => %{}, "content" => [node_for("fake_editor_form", "n2")]}

      html =
        render_component(&Athanor.Renderer.tree/1,
          tree: tree,
          ctx: Ctx.new(),
          edit_mode: true,
          show_config: false
        )

      assert html =~ ~s(data-preview="n2")
      refute html =~ "edit panel"
    end

    test "edit_mode=false → calls render/3 regardless of show_config" do
      set_components([EditorFormFake])
      tree = %{"metadata" => %{}, "content" => [node_for("fake_editor_form", "n3")]}

      html_unset =
        render_component(&Athanor.Renderer.tree/1,
          tree: tree,
          ctx: Ctx.new(),
          edit_mode: false,
          show_config: false
        )

      html_set =
        render_component(&Athanor.Renderer.tree/1,
          tree: tree,
          ctx: Ctx.new(),
          edit_mode: false,
          show_config: true
        )

      assert html_unset =~ ~s(data-preview="n3")
      assert html_set =~ ~s(data-preview="n3")
      refute html_unset =~ "edit panel"
      refute html_set =~ "edit panel"
    end

    test "editor_form returning nil → falls through to render/3 even in edit+config mode" do
      set_components([NoEditorFormFake])
      tree = %{"metadata" => %{}, "content" => [node_for("fake_no_editor_form", "n4")]}

      html =
        render_component(&Athanor.Renderer.tree/1,
          tree: tree,
          ctx: Ctx.new(),
          edit_mode: true,
          show_config: true
        )

      assert html =~ ~s(data-no-form="n4")
    end
  end
end
