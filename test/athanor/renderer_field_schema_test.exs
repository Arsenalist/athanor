defmodule Athanor.RendererFieldSchemaTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Athanor.Ctx

  alias Athanor.Test.FakeComponents.{
    EditorFormFake,
    FieldsAndEditorFormFake,
    FieldsOnlyFake,
    Minimal,
    NoEditorFormFake,
    WithRender
  }

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

  defp render_dispatch(modules, type, opts) do
    set_components(modules)
    tree = %{"metadata" => %{}, "content" => [node_for(type, "n1")]}

    render_component(&Athanor.Renderer.tree/1,
      tree: tree,
      ctx: Ctx.new(),
      edit_mode: Keyword.get(opts, :edit_mode, false),
      show_config: Keyword.get(opts, :show_config, false)
    )
  end

  # ---------------------------------------------------------------------------
  # CURRENT BEHAVIOR LOCKDOWN — these tests must keep passing after the
  # Phase 4 dispatch change.
  # ---------------------------------------------------------------------------

  describe "legacy editor_form/0 path (UNCHANGED)" do
    test "edit + config + editor_form/0 returns module → that LC mounts" do
      html =
        render_dispatch([EditorFormFake], "fake_editor_form",
          edit_mode: true,
          show_config: true
        )

      assert html =~ ~s(data-editor-form-fake-lc="n1")
      refute html =~ "preview"
    end

    test "editor_form/0 returns nil → falls through to render/3" do
      html =
        render_dispatch([NoEditorFormFake], "fake_no_editor_form",
          edit_mode: true,
          show_config: true
        )

      assert html =~ ~s(data-no-form="n1")
    end

    test "edit + show_config=false → preview path, never the editor LC" do
      html =
        render_dispatch([EditorFormFake], "fake_editor_form",
          edit_mode: true,
          show_config: false
        )

      assert html =~ ~s(data-preview="n1")
      refute html =~ "edit panel"
    end

    test "storefront (edit_mode=false) → preview, never editor LC" do
      html = render_dispatch([EditorFormFake], "fake_editor_form", edit_mode: false)

      assert html =~ ~s(data-preview="n1")
      refute html =~ "edit panel"
    end
  end

  # ---------------------------------------------------------------------------
  # NEW: fields/0 path
  # ---------------------------------------------------------------------------

  describe "fields/0 path (NEW)" do
    test "edit + config + non-empty fields/0 → AutoEditorForm mounts" do
      html =
        render_dispatch([FieldsOnlyFake], "fake_fields_only",
          edit_mode: true,
          show_config: true
        )

      assert html =~ ~s(data-testid="athanor-auto-editor-form")
      # Title field from FieldsOnlyFake.fields/0 should render in the auto-form
      assert html =~ "Title"
      # NOT the preview render
      refute html =~ ~s(data-fields-only-preview)
    end

    test "edit + show_config=false → preview path, never auto-form" do
      html =
        render_dispatch([FieldsOnlyFake], "fake_fields_only",
          edit_mode: true,
          show_config: false
        )

      assert html =~ ~s(data-fields-only-preview="n1")
      refute html =~ ~s(data-testid="athanor-auto-editor-form")
    end

    test "storefront → preview, never auto-form" do
      html = render_dispatch([FieldsOnlyFake], "fake_fields_only", edit_mode: false)

      assert html =~ ~s(data-fields-only-preview="n1")
      refute html =~ ~s(data-testid="athanor-auto-editor-form")
    end
  end

  # ---------------------------------------------------------------------------
  # Priority test — fields/0 wins when both defined
  # ---------------------------------------------------------------------------

  describe "fields/0 priority over editor_form/0" do
    test "edit + config + fields/0 AND editor_form/0 → AutoEditorForm wins" do
      html =
        render_dispatch(
          [FieldsAndEditorFormFake],
          "fake_fields_and_editor_form",
          edit_mode: true,
          show_config: true
        )

      assert html =~ ~s(data-testid="athanor-auto-editor-form")
      # the editor_form LC's marker must NOT appear
      refute html =~ ~s(data-editor-form-fake-lc)
    end
  end

  # ---------------------------------------------------------------------------
  # Empty fields/0 = legacy behavior (Heading/Button/Divider during Phase 4)
  # ---------------------------------------------------------------------------

  describe "fields/0 returning [] is treated as no-fields (legacy path)" do
    # Minimal has fields() returning [] via the `use Athanor.Component` default
    # AND no editor_form/0 → should fall through to preview.

    test "edit + config + fields() == [] + no editor_form → no config panel; falls to preview path" do
      html =
        render_dispatch([Minimal], "fake_minimal",
          edit_mode: true,
          show_config: true
        )

      # Minimal has render/3 NOT exported (only metadata). So it falls all
      # the way through to the legacy adapter path. Either an empty body,
      # a placeholder, or the legacy unwired marker — the key is that
      # neither AutoEditorForm nor an editor_form LC is mounted.
      refute html =~ ~s(data-testid="athanor-auto-editor-form")
    end

    test "edit + config + fields() == [] + editor_form returns module → editor_form path" do
      html =
        render_dispatch([EditorFormFake], "fake_editor_form",
          edit_mode: true,
          show_config: true
        )

      # editor_form/0 path still mounts EditorFormFakeLC because fields()
      # returns the injected empty list.
      assert html =~ ~s(data-editor-form-fake-lc="n1")
      refute html =~ ~s(data-testid="athanor-auto-editor-form")
    end
  end

  # ---------------------------------------------------------------------------
  # Preview render path unchanged for fields-based components
  # ---------------------------------------------------------------------------

  describe "render/3 path unchanged" do
    test "fields-based component still renders preview via render/3 on storefront" do
      html = render_dispatch([WithRender], "fake_with_render", edit_mode: false)

      assert html =~ ~s(data-fake-render="n1")
    end
  end
end
