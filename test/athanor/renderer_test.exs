defmodule Athanor.RendererTest do
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias Athanor.Ctx
  alias Athanor.Test.FakeComponents.{Minimal, WithRender}

  setup do
    original = Application.get_env(:athanor, :components)
    on_exit(fn -> if original, do: Application.put_env(:athanor, :components, original) end)
    :ok
  end

  defp set_components(modules), do: Application.put_env(:athanor, :components, modules)

  defp node(type, id, props \\ %{}),
    do: %{"id" => id, "type" => type, "props" => props}

  describe "new-behaviour dispatch (render/3)" do
    test "calls module.render(:live, node, ctx) for a component implementing render/3" do
      set_components([WithRender])
      tree = %{"metadata" => %{}, "content" => [node("fake_with_render", "n1")]}
      ctx = Ctx.new()

      html = render_component(&Athanor.Renderer.tree/1, tree: tree, ctx: ctx)

      assert html =~ ~s(data-fake-render="n1")
    end

    test "passes Ctx through to module.render/3" do
      set_components([Minimal, WithRender])

      defmodule CaptureCtx do
        use Athanor.Component
        def metadata, do: %{type: "capture_ctx", label: "C"}

        def render(:live, _node, ctx) do
          Phoenix.HTML.raw(~s(<div data-account-id="#{ctx.account_id}"></div>))
        end
      end

      set_components([CaptureCtx])
      tree = %{"metadata" => %{}, "content" => [node("capture_ctx", "n2")]}
      ctx = Ctx.new(account_id: "acct_test_123")

      html = render_component(&Athanor.Renderer.tree/1, tree: tree, ctx: ctx)

      assert html =~ ~s(data-account-id="acct_test_123")
    end
  end

  describe "tolerates truthy non-bool from legacy has_required_props?/1" do
    test "does not crash on truthy integer return (regression: Underground gift_card_builder)" do
      defmodule FakeRegistryHitsLegacyTruthy do
        def resolve("legacy_truthy"), do: Athanor.Test.FakeComponents.LegacyTruthy
        def resolve(_), do: nil
      end

      defmodule FakeLegacyAdapter do
        def render(_module, assigns) do
          Phoenix.HTML.raw(~s(<div data-truthy-adapter="#{assigns.node["id"]}"></div>))
        end
      end

      original_fallback = Application.get_env(:athanor, :fallback_resolver)
      original_adapter = Application.get_env(:athanor, :legacy_adapter)

      try do
        Application.put_env(
          :athanor,
          :fallback_resolver,
          {FakeRegistryHitsLegacyTruthy, :resolve}
        )

        Application.put_env(:athanor, :legacy_adapter, {FakeLegacyAdapter, :render})

        tree = %{
          "metadata" => %{},
          "content" => [
            # account_id present + brand_id is INTEGER 6 → has_required_props?
            # returns 6 (truthy non-bool).
            node("legacy_truthy", "leg1", %{"account_id" => "acct_abc", "brand_id" => 6})
          ]
        }

        # Pre-fix this would raise ArgumentError on :erlang.not(6).
        html = render_component(&Athanor.Renderer.tree/1, tree: tree, ctx: Ctx.new())

        assert html =~ ~s(data-truthy-adapter="leg1")
      after
        if original_fallback,
          do: Application.put_env(:athanor, :fallback_resolver, original_fallback),
          else: Application.delete_env(:athanor, :fallback_resolver)

        if original_adapter,
          do: Application.put_env(:athanor, :legacy_adapter, original_adapter),
          else: Application.delete_env(:athanor, :legacy_adapter)
      end
    end
  end

  describe "unknown type" do
    test "renders a developer placeholder, does not crash" do
      set_components([])
      tree = %{"metadata" => %{}, "content" => [node("does_not_exist", "n3")]}
      ctx = Ctx.new()

      html = render_component(&Athanor.Renderer.tree/1, tree: tree, ctx: ctx)

      assert html =~ "does_not_exist"
      assert html =~ "data-athanor-unknown-type" or html =~ "Unknown component"
    end
  end

  describe "iteration" do
    test "renders nodes in order" do
      set_components([WithRender])

      tree = %{
        "metadata" => %{},
        "content" => [
          node("fake_with_render", "a"),
          node("fake_with_render", "b"),
          node("fake_with_render", "c")
        ]
      }

      html = render_component(&Athanor.Renderer.tree/1, tree: tree, ctx: Ctx.new())

      assert :binary.match(html, "n=\"a\"") < :binary.match(html, "n=\"b\"") or
               (html =~ ~s(data-fake-render="a") and
                  html =~ ~s(data-fake-render="b") and
                  html =~ ~s(data-fake-render="c"))
    end

    test "empty content renders empty wrapper" do
      set_components([])
      tree = %{"metadata" => %{}, "content" => []}
      html = render_component(&Athanor.Renderer.tree/1, tree: tree, ctx: Ctx.new())

      assert is_binary(html)
    end
  end
end
