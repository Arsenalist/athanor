defmodule Athanor.Components.TextTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Athanor.Components.Text
  alias Athanor.Ctx

  defp render_node(props) do
    rendered =
      Text.render(:live, %{"id" => "t1", "type" => "text", "props" => props}, Ctx.new())

    rendered_to_string(rendered)
  end

  describe "render(:live, ...)" do
    test "simple plain text renders as raw HTML" do
      html = render_node(%{"text" => "<p>hello</p>"})
      assert html =~ "<p>hello</p>"
    end

    test "rich HTML markup preserved" do
      html =
        render_node(%{
          "text" =>
            ~s(<p>Hi <strong>bold</strong> <a href="https://x">link</a> <img src="https://x/i.jpg" alt="x"/></p>)
        })

      assert html =~ "<strong>bold</strong>"
      assert html =~ ~s(href="https://x")
      assert html =~ ~s(<img src="https://x/i.jpg")
    end

    test "formatting props produce inline style attributes" do
      html =
        render_node(%{
          "text" => "<p>hi</p>",
          "formatting" => %{
            "padding_top" => 16,
            "padding_bottom" => 12,
            "background_color" => "#fef3c7",
            "border_radius" => 8
          }
        })

      assert html =~ "padding-top: 16px"
      assert html =~ "padding-bottom: 12px"
      assert html =~ "background-color: #fef3c7"
      assert html =~ "border-radius: 8px"
    end

    test "alignment center applies class" do
      html =
        render_node(%{
          "text" => "<p>hi</p>",
          "formatting" => %{"alignment" => "center"}
        })

      assert html =~ "flex justify-center"
    end
  end

  describe "validate/1" do
    test "non-empty text → :ok" do
      assert Text.validate(%{"text" => "<p>x</p>"}) == :ok
    end

    test "empty text → error" do
      assert Text.validate(%{"text" => ""}) == {:error, {:missing, ["text"]}}
    end

    test "missing text → error" do
      assert Text.validate(%{}) == {:error, {:missing, ["text"]}}
    end

    test "nil props → error" do
      assert Text.validate(nil) == {:error, {:missing, ["text"]}}
    end
  end

  describe "behaviour metadata" do
    test "default_props" do
      assert Text.default_props() == %{"text" => ""}
    end

    test "required_props" do
      assert Text.required_props() == ["text"]
    end

    test "editor_form defaults to nil when no app config is set" do
      previous = Application.get_env(:athanor, :text_editor_form)
      Application.delete_env(:athanor, :text_editor_form)
      assert Text.editor_form() == nil
      if previous, do: Application.put_env(:athanor, :text_editor_form, previous)
    end

    test "editor_form returns the module registered in app config" do
      previous = Application.get_env(:athanor, :text_editor_form)
      Application.put_env(:athanor, :text_editor_form, SomeConsumer.RichTextLC)

      try do
        assert Text.editor_form() == SomeConsumer.RichTextLC
      after
        if previous,
          do: Application.put_env(:athanor, :text_editor_form, previous),
          else: Application.delete_env(:athanor, :text_editor_form)
      end
    end

    test "metadata type" do
      assert Text.metadata().type == "text"
    end
  end
end
