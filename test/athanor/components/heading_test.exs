defmodule Athanor.Components.HeadingTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Athanor.Components.Heading
  alias Athanor.Ctx

  defp render_node(props) do
    rendered =
      Heading.render(:live, %{"id" => "h1", "type" => "heading", "props" => props}, Ctx.new())

    rendered_to_string(rendered)
  end

  describe "render(:live, ...) per level" do
    for n <- 1..6 do
      test "level #{n} produces an h#{n} tag" do
        html = render_node(%{"text" => "Hello", "level" => unquote(n)})
        assert html =~ "<h#{unquote(n)}"
        assert html =~ "Hello"
        assert html =~ "</h#{unquote(n)}>"
      end
    end
  end

  describe "level clamping" do
    test "level > 6 clamps to 6" do
      html = render_node(%{"text" => "Hi", "level" => 99})
      assert html =~ "<h6"
    end

    test "level < 1 clamps to 1" do
      html = render_node(%{"text" => "Hi", "level" => -1})
      assert html =~ "<h1"
    end

    test "non-integer level falls back to 2" do
      html = render_node(%{"text" => "Hi", "level" => "not a number"})
      assert html =~ "<h2"
    end

    test "missing level defaults to 2" do
      html = render_node(%{"text" => "Hi"})
      assert html =~ "<h2"
    end
  end

  describe "formatting wrap" do
    test "formatting.alignment center applies flex class" do
      html = render_node(%{"text" => "Hi", "formatting" => %{"alignment" => "center"}})
      assert html =~ "flex justify-center"
    end

    test "formatting padding/background applied as inline style" do
      html =
        render_node(%{
          "text" => "Hi",
          "formatting" => %{"padding_top" => 24, "background_color" => "#eef2ff"}
        })

      assert html =~ "padding-top: 24px"
      assert html =~ "background-color: #eef2ff"
    end

    test "no formatting → empty class + empty style" do
      html = render_node(%{"text" => "Hi"})
      assert html =~ ~s(class=")
      assert html =~ ~s(style=")
      assert html =~ "<h2"
    end
  end

  describe "behaviour metadata" do
    test "default_props (alignment now lives in formatting)" do
      assert Heading.default_props() == %{
               "text" => "Heading text",
               "level" => 2
             }
    end

    test "required_props" do
      assert Heading.required_props() == ["text"]
    end

    test "editor_form returns the form module" do
      assert Heading.editor_form() == Athanor.Components.Heading.EditorForm
    end

    test "metadata shape" do
      meta = Heading.metadata()
      assert meta.type == "heading"
      assert meta.label == "Heading"
    end
  end
end
