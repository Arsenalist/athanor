defmodule Athanor.ComponentTest do
  use ExUnit.Case, async: true

  alias Athanor.Test.FakeComponents.{Minimal, Required, WithRender}

  describe "use Athanor.Component" do
    test "minimal component compiles with only metadata/0 defined" do
      assert Minimal.metadata().type == "fake_minimal"
      assert Minimal.metadata().label == "Minimal"
    end

    test "injects no-op defaults for optional callbacks" do
      assert Minimal.default_props() == %{}
      assert Minimal.required_props() == []
      assert Minimal.validate(%{}) == :ok
      assert Minimal.editor_form() == nil
      assert Minimal.child_zones(%{"props" => %{}}) == %{}
    end
  end

  describe "default validate/1 derived from required_props/0" do
    test "returns :ok when all required props present" do
      assert Required.validate(%{"title" => "Hi", "body" => "there"}) == :ok
    end

    test "returns {:error, {:missing, [...]}} listing missing keys" do
      assert Required.validate(%{"title" => "Hi"}) == {:error, {:missing, ["body"]}}
    end

    test "considers blank strings as missing" do
      assert Required.validate(%{"title" => "", "body" => "x"}) ==
               {:error, {:missing, ["title"]}}
    end

    test "considers nil as missing" do
      assert Required.validate(%{"title" => nil, "body" => "x"}) ==
               {:error, {:missing, ["title"]}}
    end
  end

  describe "render/3 detection" do
    test "function_exported? returns true when component implements render/3" do
      Code.ensure_loaded!(WithRender)
      assert function_exported?(WithRender, :render, 3)
    end

    test "function_exported? returns false when component lacks render/3" do
      Code.ensure_loaded!(Minimal)
      refute function_exported?(Minimal, :render, 3)
    end
  end

  describe "metadata shape" do
    test "required fields :type and :label present" do
      meta = Minimal.metadata()
      assert is_binary(meta.type) and meta.type != ""
      assert is_binary(meta.label) and meta.label != ""
    end
  end
end
