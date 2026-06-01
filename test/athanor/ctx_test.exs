defmodule Athanor.CtxTest do
  use ExUnit.Case, async: true

  alias Athanor.Ctx

  doctest Athanor.Ctx

  describe "new/0" do
    test "returns a struct with all default fields nil/empty" do
      ctx = Ctx.new()

      assert %Ctx{} = ctx
      assert ctx.user_id == nil
      assert ctx.account_id == nil
      assert ctx.api_token == nil
      assert ctx.brand_id == nil
      assert ctx.cart_id == nil
      assert ctx.asset_picker == nil
      assert ctx.rich_text == nil
      assert ctx.data_sources == %{}
      assert ctx.i18n == nil
      assert ctx.extra == %{}
    end
  end

  describe "new/1" do
    test "accepts a keyword list of overrides" do
      ctx = Ctx.new(user_id: "u1", account_id: "a1", brand_id: "b1")

      assert ctx.user_id == "u1"
      assert ctx.account_id == "a1"
      assert ctx.brand_id == "b1"
      assert ctx.cart_id == nil
    end

    test "accepts a map of overrides" do
      ctx = Ctx.new(%{cart_id: "cart_xyz", extra: %{tenant: "acme"}})

      assert ctx.cart_id == "cart_xyz"
      assert ctx.extra == %{tenant: "acme"}
    end

    test "rejects unknown keys with a clear error" do
      assert_raise KeyError, fn ->
        Ctx.new(not_a_field: "boom")
      end
    end
  end

  describe "extra map" do
    test "is free-form — Athanor never inspects it" do
      ctx = Ctx.new(extra: %{any_key: 1, other_key: %{nested: true}})

      assert ctx.extra == %{any_key: 1, other_key: %{nested: true}}
    end
  end

  describe "struct round-trip" do
    test "Map.from_struct converts cleanly for inspection / logging" do
      ctx = Ctx.new(user_id: "u1", cart_id: "c1")
      m = Map.from_struct(ctx)

      assert m.user_id == "u1"
      assert m.cart_id == "c1"
      refute Map.has_key?(m, :__struct__)
    end
  end
end
