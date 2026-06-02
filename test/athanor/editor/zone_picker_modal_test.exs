defmodule Athanor.Editor.ZonePickerModalTest do
  @moduledoc """
  Tests for `Athanor.Editor.zone_picker_modal/1` — a function component
  rendered on the editor's modal layer when `column_picker` is set
  (triggered by a Columns child's "Add Component" button).

  Renders a palette of available components scoped by
  `Athanor.Registry.components_metadata/0` and on submit emits the
  consumer-handled `"add_component_to_zone"` event.
  """

  use ExUnit.Case, async: false
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Editor

  defmodule FakeText do
    use Athanor.Component
    def metadata, do: %{type: "fake_text", label: "FakeText"}
  end

  setup do
    Application.put_env(:athanor, :components, [FakeText])
    on_exit(fn -> Application.put_env(:athanor, :components, []) end)
    :ok
  end

  defp render_modal(column_picker) do
    render_component(
      fn assigns ->
        ~H"""
        <Editor.zone_picker_modal column_picker={@column_picker} />
        """
      end,
      %{column_picker: column_picker}
    )
  end

  describe "rendering" do
    test "nil column_picker → nothing rendered" do
      html = render_modal(nil)
      refute html =~ ~s(data-testid="zone-picker-modal")
    end

    test "set column_picker → modal rendered with parent + zone hidden inputs" do
      html = render_modal({"col1", "one"})
      assert html =~ ~s(data-testid="zone-picker-modal")
      assert html =~ ~s(name="parent_id" value="col1")
      assert html =~ ~s(name="zone_name" value="one")
    end

    test "form fires add_component_to_zone on submit" do
      html = render_modal({"col1", "one"})
      assert html =~ ~s(phx-submit="add_component_to_zone")
    end

    test "cancel button fires cancel_zone_picker" do
      html = render_modal({"col1", "one"})
      assert html =~ ~s(phx-click="cancel_zone_picker")
    end

    test "lists registered components as picker options" do
      html = render_modal({"col1", "one"})
      assert html =~ "FakeText"
      assert html =~ ~s(value="fake_text")
    end
  end
end
