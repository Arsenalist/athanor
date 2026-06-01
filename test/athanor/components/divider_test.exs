defmodule Athanor.Components.DividerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Athanor.Components.Divider
  alias Athanor.Ctx

  defp render_node(props) do
    rendered =
      Divider.render(:live, %{"id" => "d1", "type" => "divider", "props" => props}, Ctx.new())

    rendered_to_string(rendered)
  end

  describe "render(:live, ...)" do
    test "renders hr with default style" do
      html = render_node(%{})
      assert html =~ "<hr"
      assert html =~ "border-top-width:1px"
      assert html =~ "border-color:#e5e7eb"
      assert html =~ "my-md"
    end

    test "thickness clamps to 0..16" do
      assert render_node(%{"thickness" => 999}) =~ "border-top-width:16px"
      assert render_node(%{"thickness" => -5}) =~ "border-top-width:0px"
    end

    test "non-integer thickness falls back to 1" do
      assert render_node(%{"thickness" => "abc"}) =~ "border-top-width:1px"
    end

    test "valid hex color passes through" do
      assert render_node(%{"color" => "#ff0000"}) =~ "border-color:#ff0000"
    end

    test "invalid color falls back to default" do
      assert render_node(%{"color" => "red"}) =~ "border-color:#e5e7eb"
      assert render_node(%{"color" => "#ZZZZZZ"}) =~ "border-color:#e5e7eb"
    end

    test "valid margin_y values" do
      for m <- ["sm", "md", "lg"] do
        assert render_node(%{"margin_y" => m}) =~ "my-#{m}", "margin #{m}"
      end
    end

    test "unknown margin_y falls back to md" do
      assert render_node(%{"margin_y" => "weird"}) =~ "my-md"
    end
  end

  describe "behaviour metadata" do
    test "required_props is empty (always renders)" do
      assert Divider.required_props() == []
    end

    test "default_props shape" do
      assert Divider.default_props() == %{
               "thickness" => 1,
               "color" => "#e5e7eb",
               "margin_y" => "md"
             }
    end

    test "editor_form returns the form module" do
      assert Divider.editor_form() == Athanor.Components.Divider.EditorForm
    end

    test "metadata category is :layout" do
      assert Divider.metadata().category == :layout
    end
  end
end
