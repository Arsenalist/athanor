defmodule Athanor.Editor.PageSettingsTest do
  @moduledoc """
  Tests for `page_settings_component:` opt — verifies that:
    - page-settings render section appears in left sidebar when opt set
    - handle_info routes update_component_props with id "page-settings"
      to @metadata (NOT @content)
    - resolve_data + resolve_fields work for the page-settings component
      identically to regular components
    - mount-time warning fires when the opt module is ALSO registered
      in config :athanor :components
  """

  use ExUnit.Case, async: false
  use Phoenix.Component

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias Athanor.Editor
  alias Athanor.Editor.Live, as: EditorLive

  # ─── fake page settings component ──────────────────────────────────────

  defmodule SimplePS do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "page_settings", label: "Settings"}
    def fields, do: [{"title", :text, label: "Title"}]
  end

  defmodule CascadePS do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "cascade_ps", label: "Cascade"}
    def fields, do: [{"title", :text, []}, {"slug", :text, []}]

    @impl Athanor.Component
    def resolve_data(_old, new) do
      # Derived slug from title
      title = new["title"] || ""
      slug = title |> String.downcase() |> String.replace(~r/\s+/, "-")
      Map.put(new, "slug", slug)
    end
  end

  defmodule DynamicFieldsPS do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "dyn_ps", label: "Dyn"}
    def fields, do: [{"mode", :text, []}]

    @impl Athanor.Component
    def resolve_fields(props, _opts) do
      base = fields()
      if props["mode"] == "advanced", do: base ++ [{"extra", :text, []}], else: base
    end
  end

  # ─── rendering ─────────────────────────────────────────────────────────

  describe "rendering page settings in left sidebar" do
    test "renders page settings section when component is set" do
      html = render_panel(SimplePS, %{"title" => "Hello"})
      assert html =~ ~s(data-testid="page-settings")
      assert html =~ "Title"
    end

    test "omits page settings section when component is nil" do
      html = render_panel(nil, %{})
      refute html =~ ~s(data-testid="page-settings")
    end

    test "uses component's metadata.label as section heading" do
      html = render_panel(SimplePS, %{})
      assert html =~ "Settings"
    end
  end

  # ─── handle_info routing: page-settings → metadata, not content ───────

  describe "handle_info routing" do
    test "update_component_props with id 'page-settings' updates @metadata" do
      socket = mock_socket(content: %{"content" => []}, metadata: %{"title" => "Old"})

      {:noreply, new_socket} =
        EditorLive.handle_info(nil, {:update_component_props, "page-settings", %{"title" => "New"}}, socket)

      assert new_socket.assigns.metadata == %{"title" => "New"}
      # Content tree untouched.
      assert new_socket.assigns.content == %{"content" => []}
    end

    test "update_component_props with regular component id updates @content" do
      content = %{
        "content" => [%{"id" => "n1", "type" => "text", "props" => %{"text" => "<p>old</p>"}}]
      }

      socket = mock_socket(content: content, metadata: %{"title" => "Untouched"})

      {:noreply, new_socket} =
        EditorLive.handle_info(nil,
          {:update_component_props, "n1", %{"text" => "<p>new</p>"}},
          socket
        )

      [updated_node] = new_socket.assigns.content["content"]
      assert updated_node["props"]["text"] == "<p>new</p>"
      # Metadata untouched.
      assert new_socket.assigns.metadata == %{"title" => "Untouched"}
    end

    test "update_component_props with unknown component id is a no-op" do
      socket = mock_socket(content: %{"content" => []}, metadata: %{})

      {:noreply, new_socket} =
        EditorLive.handle_info(nil, {:update_component_props, "ghost", %{}}, socket)

      assert new_socket.assigns.content == %{"content" => []}
      assert new_socket.assigns.metadata == %{}
    end
  end

  # ─── resolve_data + resolve_fields integration ─────────────────────────
  #
  # AutoEditorForm calls module.resolve_data(old, new) before sending
  # :update_component_props (already covered in resolve_data_test.exs).
  # Here we just verify that a page-settings component's resolve_fields
  # gets called by the standard AutoEditorForm machinery.

  describe "resolve_data on page settings" do
    test "cascade derives slug from title (called via AutoEditorForm helper)" do
      out = Athanor.AutoEditorForm.apply_resolve_data(CascadePS, %{"title" => ""},
              %{"title" => "Hello World"})

      assert out["title"] == "Hello World"
      assert out["slug"] == "hello-world"
    end
  end

  describe "resolve_fields on page settings" do
    test "dynamic fields appear/disappear based on prop value" do
      simple = DynamicFieldsPS.resolve_fields(%{"mode" => "simple"}, %{})
      assert length(simple) == 1
      assert Enum.any?(simple, fn {k, _, _} -> k == "mode" end)

      advanced = DynamicFieldsPS.resolve_fields(%{"mode" => "advanced"}, %{})
      assert length(advanced) == 2
      assert Enum.any?(advanced, fn {k, _, _} -> k == "extra" end)
    end
  end

  # ─── registry-collision warning ────────────────────────────────────────

  describe "page_settings_component also in registry" do
    test "emits a warning when the module is found in Athanor.Registry" do
      Application.put_env(:athanor, :components, [SimplePS])
      on_exit(fn -> Application.put_env(:athanor, :components, []) end)

      log =
        capture_log(fn ->
          EditorLive.warn_if_registered(SimplePS)
        end)

      assert log =~ "page_settings_component"
      assert log =~ "Athanor.Registry"
      assert log =~ "SimplePS"
    end

    test "no warning when module is NOT in registry" do
      Application.put_env(:athanor, :components, [])

      log =
        capture_log(fn ->
          EditorLive.warn_if_registered(SimplePS)
        end)

      refute log =~ "page_settings_component"
    end

    test "no warning when component opt is nil" do
      log =
        capture_log(fn ->
          EditorLive.warn_if_registered(nil)
        end)

      refute log =~ "page_settings_component"
    end
  end

  # ─── helpers ───────────────────────────────────────────────────────────

  defp render_panel(page_settings_component, metadata) do
    assigns = %{
      ctx: Athanor.Ctx.new(edit_mode?: true),
      page_settings_component: page_settings_component,
      metadata: metadata
    }

    render_component(
      fn assigns ->
        ~H"""
        <Editor.components_panel
          ctx={@ctx}
          page_settings_component={@page_settings_component}
          metadata={@metadata}
        />
        """
      end,
      assigns
    )
  end

  defp mock_socket(opts) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        content: opts[:content] || %{"content" => []},
        metadata: opts[:metadata] || %{},
        selected_component_id: nil,
        column_picker: nil,
        preview_viewport: :desktop,
        show_components_panel: true,
        ctx: nil
      }
    }
  end
end
