defmodule Athanor.Components.Formatting.EditorFormTest do
  use ExUnit.Case, async: true

  alias Athanor.Components.Formatting.EditorForm

  describe "build_form/1" do
    test "fills in defaults for missing fields" do
      form = EditorForm.build_form(%{})

      assert form[:text_color].value == ""
      assert form[:background_color].value == ""
      assert form[:border_color].value == ""
      assert form[:padding_top].value == 0
      assert form[:padding_bottom].value == 0
      assert form[:margin_top].value == 0
      assert form[:border_radius].value == 0
      assert form[:border_width].value == 0
      assert form[:alignment].value == "left"
    end

    test "preserves supplied values" do
      form =
        EditorForm.build_form(%{
          "text_color" => "#ff0000",
          "padding_top" => 16,
          "alignment" => "center"
        })

      assert form[:text_color].value == "#ff0000"
      assert form[:padding_top].value == 16
      assert form[:alignment].value == "center"
    end

    test "non-map input returns empty form" do
      form = EditorForm.build_form(nil)
      assert form[:alignment].value == "left"
    end
  end

  describe "coerce_params/1" do
    test "string integers convert to integers" do
      params = %{
        "padding_top" => "16",
        "padding_bottom" => "8",
        "margin_left" => "4",
        "border_radius" => "12",
        "text_color" => "#ff0000",
        "alignment" => "center"
      }

      coerced = EditorForm.coerce_params(params)

      assert coerced["padding_top"] == 16
      assert coerced["padding_bottom"] == 8
      assert coerced["margin_left"] == 4
      assert coerced["border_radius"] == 12
      assert coerced["text_color"] == "#ff0000"
      assert coerced["alignment"] == "center"
    end

    test "empty strings on number fields → 0" do
      coerced = EditorForm.coerce_params(%{"padding_top" => "", "margin_top" => ""})
      assert coerced["padding_top"] == 0
      assert coerced["margin_top"] == 0
    end

    test "missing alignment → 'left'" do
      coerced = EditorForm.coerce_params(%{})
      assert coerced["alignment"] == "left"
    end

    test "non-numeric strings on number fields → 0 (defensive)" do
      coerced = EditorForm.coerce_params(%{"padding_top" => "bogus"})
      assert coerced["padding_top"] == 0
    end

    test "produces all 14 keys" do
      coerced = EditorForm.coerce_params(%{})

      for required <- ~w(text_color background_color border_color
                         padding_top padding_bottom padding_left padding_right
                         margin_top margin_bottom margin_left margin_right
                         border_radius border_width
                         alignment) do
        assert Map.has_key?(coerced, required), "missing #{required}"
      end
    end
  end

  describe "default_open_sections/0" do
    test "returns MapSet with colors open by default (matches legacy)" do
      sections = EditorForm.default_open_sections()
      assert MapSet.member?(sections, "colors")
    end
  end

  describe "toggle_section/2" do
    test "adds a missing section" do
      result = EditorForm.toggle_section(MapSet.new(), "padding")
      assert MapSet.member?(result, "padding")
    end

    test "removes an existing section" do
      result = EditorForm.toggle_section(MapSet.new(["padding"]), "padding")
      refute MapSet.member?(result, "padding")
    end

    test "leaves other sections untouched" do
      result = EditorForm.toggle_section(MapSet.new(["colors", "padding"]), "padding")
      assert MapSet.member?(result, "colors")
      refute MapSet.member?(result, "padding")
    end
  end
end
