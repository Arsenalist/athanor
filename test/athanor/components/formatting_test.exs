defmodule Athanor.Components.FormattingTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Components.Formatting

  describe "build_style/1" do
    test "returns string of fragments separated by ;" do
      style = Formatting.build_style(%{"padding_top" => 16, "background_color" => "#fef3c7"})

      assert style =~ "padding-top: 16px"
      assert style =~ "background-color: #fef3c7"
    end

    test "omits blank colors (no key)" do
      style = Formatting.build_style(%{"padding_top" => 8})

      refute style =~ "color:"
      refute style =~ "background-color:"
    end

    test "omits empty-string colors" do
      style = Formatting.build_style(%{"text_color" => "", "background_color" => ""})

      refute style =~ "color:"
      refute style =~ "background-color:"
    end

    test "integer px fields render as px" do
      style =
        Formatting.build_style(%{
          "padding_top" => 1,
          "padding_bottom" => 2,
          "padding_left" => 3,
          "padding_right" => 4,
          "margin_top" => 5,
          "margin_bottom" => 6,
          "margin_left" => 7,
          "margin_right" => 8,
          "border_radius" => 9,
          "border_width" => 10
        })

      for {label, n} <- [
            {"padding-top", 1},
            {"padding-bottom", 2},
            {"padding-left", 3},
            {"padding-right", 4},
            {"margin-top", 5},
            {"margin-bottom", 6},
            {"margin-left", 7},
            {"margin-right", 8},
            {"border-radius", 9},
            {"border-width", 10}
          ] do
        assert style =~ "#{label}: #{n}px", "expected #{label}: #{n}px"
      end
    end

    test "string-numeric px fields coerce to integer" do
      style = Formatting.build_style(%{"padding_top" => "12"})
      assert style =~ "padding-top: 12px"
    end

    test "non-numeric strings on px fields are dropped" do
      style = Formatting.build_style(%{"padding_top" => "huge"})
      refute style =~ "padding-top"
    end

    test "nil formatting returns empty string" do
      assert Formatting.build_style(nil) == ""
    end
  end

  describe "alignment_class/1" do
    test "center maps to flex justify-center" do
      assert Formatting.alignment_class(%{"alignment" => "center"}) == "flex justify-center"
    end

    test "right maps to flex justify-end" do
      assert Formatting.alignment_class(%{"alignment" => "right"}) == "flex justify-end"
    end

    test "left or unknown → empty string" do
      assert Formatting.alignment_class(%{"alignment" => "left"}) == ""
      assert Formatting.alignment_class(%{"alignment" => "weird"}) == ""
      assert Formatting.alignment_class(%{}) == ""
      assert Formatting.alignment_class(nil) == ""
    end
  end

  describe "apply/1 (function component)" do
    test "wraps content with class + style derived from formatting" do
      assigns = %{
        formatting: %{
          "alignment" => "center",
          "padding_top" => 12,
          "background_color" => "#ffeb3b"
        },
        inner: nil
      }

      rendered =
        render_component(
          fn assigns ->
            ~H"""
            <Formatting.apply formatting={@formatting}>
              <p>marker</p>
            </Formatting.apply>
            """
          end,
          assigns
        )

      assert rendered =~ "flex justify-center"
      assert rendered =~ "padding-top: 12px"
      assert rendered =~ "background-color: #ffeb3b"
      assert rendered =~ "<p>marker</p>"
    end

    test "no formatting still wraps content in div" do
      rendered =
        render_component(
          fn assigns ->
            ~H"""
            <Formatting.apply formatting={%{}}>
              <p>plain</p>
            </Formatting.apply>
            """
          end,
          %{}
        )

      assert rendered =~ "<p>plain</p>"
    end
  end

  describe "style_options/0" do
    test "lists all 13 style keys" do
      keys = Formatting.style_options()

      for required <- ~w(text_color background_color
                         padding_top padding_bottom padding_left padding_right
                         margin_top margin_bottom margin_left margin_right
                         border_radius border_width border_color) do
        assert required in keys, "missing #{required}"
      end

      assert length(keys) == 13
    end
  end
end
