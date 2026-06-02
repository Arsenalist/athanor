defmodule Athanor.Editor.ComponentsPanelTest do
  @moduledoc """
  Tests for `Athanor.Editor.components_panel/1` — the left-sidebar
  content. Renders the components palette from
  `Athanor.Registry.components_metadata/0` and, when a
  `page_settings_component` is provided, renders that component's form
  via `Athanor.AutoEditorForm` at the top of the panel.
  """

  use ExUnit.Case, async: false
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Ctx
  alias Athanor.Editor

  defmodule FakeText do
    use Athanor.Component
    def metadata, do: %{type: "fake_text", label: "FakeText", icon: "fa-text"}
  end

  defmodule FakeImage do
    use Athanor.Component
    def metadata, do: %{type: "fake_image", label: "FakeImage", icon: "fa-img"}
  end

  defmodule PageSettings do
    use Athanor.Component
    def metadata, do: %{type: "page_settings", label: "Page Settings"}
    def fields, do: [{"title", :text, label: "Title"}]
  end

  setup do
    Application.put_env(:athanor, :components, [FakeText, FakeImage])
    on_exit(fn -> Application.put_env(:athanor, :components, []) end)
    :ok
  end

  describe "components palette" do
    test "renders one entry per registered component" do
      html = render_panel()
      assert html =~ "FakeText"
      assert html =~ "FakeImage"
    end

    test "each palette item carries phx-click=\"add_component\" + phx-value-type" do
      html = render_panel()
      assert html =~ ~s(phx-click="add_component")
      assert html =~ ~s(phx-value-type="fake_text")
      assert html =~ ~s(phx-value-type="fake_image")
    end
  end

  describe "page settings (optional)" do
    test "renders the page-settings form when component is provided" do
      html = render_panel(page_settings_component: PageSettings, metadata: %{"title" => "Hello"})
      assert html =~ ~s(data-testid="page-settings")
      # AutoEditorForm dropping the field's label
      assert html =~ "Title"
    end

    test "omits the page-settings section when component is nil" do
      html = render_panel(page_settings_component: nil)
      refute html =~ ~s(data-testid="page-settings")
    end

    test "page-settings section sits ABOVE the palette" do
      html = render_panel(page_settings_component: PageSettings, metadata: %{})

      pos_settings = :binary.match(html, ~s(data-testid="page-settings")) |> elem(0)
      pos_palette = :binary.match(html, "FakeText") |> elem(0)

      assert pos_settings < pos_palette
    end
  end

  defp render_panel(opts \\ []) do
    assigns = %{
      ctx: opts[:ctx] || Ctx.new(edit_mode?: true),
      page_settings_component: opts[:page_settings_component],
      metadata: opts[:metadata] || %{}
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
end
