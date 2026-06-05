defmodule Athanor.Editor.StateTest do
  use ExUnit.Case, async: true

  alias Athanor.Editor.State

  describe "new/0" do
    test "defaults" do
      s = State.new()
      assert s.content == %{"content" => []}
      assert s.metadata == %{}
      assert s.selected_component_id == nil
      assert s.column_picker == nil
      assert s.preview_viewport == :desktop
      assert s.show_components_panel == true
      assert s.ctx == nil
    end
  end

  describe "new/1 with overrides" do
    test "keyword overrides" do
      s = State.new(preview_viewport: :tablet, selected_component_id: "n1")
      assert s.preview_viewport == :tablet
      assert s.selected_component_id == "n1"
      # Untouched defaults preserved.
      assert s.metadata == %{}
    end

    test "map overrides" do
      s = State.new(%{show_components_panel: false})
      assert s.show_components_panel == false
    end

    test "unknown keys raise" do
      assert_raise KeyError, fn -> State.new(bogus: true) end
    end
  end

  describe "asset_request" do
    test "defaults to nil" do
      assert State.new().asset_request == nil
    end

    test "round-trips an override" do
      req = %Athanor.Editor.AssetRequest{node_id: "n1", key: "hero"}
      assert State.new(asset_request: req).asset_request == req
    end
  end
end
