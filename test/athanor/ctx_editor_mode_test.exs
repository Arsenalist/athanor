defmodule Athanor.CtxEditorModeTest do
  @moduledoc """
  Tests for the editor-mode fields on Athanor.Ctx — `edit_mode?` and
  `add_component_callback`. These let render(:live) implementations
  branch between storefront and editor canvas chrome, and let container
  components (Columns) defer "add child to zone" UI to the consumer's
  palette.
  """

  use ExUnit.Case, async: true

  alias Athanor.Ctx

  describe "default values" do
    test "edit_mode? defaults to false" do
      assert Ctx.new().edit_mode? == false
    end

    test "add_component_callback defaults to nil" do
      assert Ctx.new().add_component_callback == nil
    end
  end

  describe "overrides" do
    test "edit_mode? can be set" do
      assert Ctx.new(edit_mode?: true).edit_mode? == true
    end

    test "add_component_callback can be set to a 1-arity fn" do
      cb = fn _zone -> :ok end
      ctx = Ctx.new(add_component_callback: cb)
      assert is_function(ctx.add_component_callback, 1)
    end
  end
end
