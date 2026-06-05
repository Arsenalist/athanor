defmodule Athanor.Editor.AssetRequestTest do
  use ExUnit.Case, async: true

  alias Athanor.Editor.AssetRequest

  describe "construction" do
    test "builds with the enforced keys" do
      req = %AssetRequest{node_id: "n1", key: "image"}
      assert req.node_id == "n1"
      assert req.key == "image"
    end

    test "optional fields default to nil" do
      req = %AssetRequest{node_id: "n1", key: "image"}
      assert req.accept == nil
      assert req.multiple == nil
      assert req.min == nil
      assert req.max == nil
      assert req.current == nil
    end

    test "carries the field declaration + current value" do
      req = %AssetRequest{
        node_id: "n1",
        key: "gallery",
        accept: "image/*",
        multiple: true,
        max: 12,
        min: 1,
        current: [%{"url" => "u"}]
      }

      assert req.accept == "image/*"
      assert req.multiple == true
      assert req.max == 12
      assert req.min == 1
      assert req.current == [%{"url" => "u"}]
    end

    test "raises without node_id" do
      assert_raise ArgumentError, fn ->
        struct!(AssetRequest, key: "image")
      end
    end

    test "raises without key" do
      assert_raise ArgumentError, fn ->
        struct!(AssetRequest, node_id: "n1")
      end
    end
  end
end
