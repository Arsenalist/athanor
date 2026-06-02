defmodule Athanor.ResolveFieldsTest do
  @moduledoc """
  Tests for Athanor.Component's resolve_fields/2 callback.

  Mirrors Puck's resolveFields: lets a component declare fields whose
  configuration depends on current prop values. Default impl returns
  module.fields() — backward compatible.

  Athanor.Fields.render calls resolve_fields(props, opts) instead of
  fields/0 so the field list can change dynamically per-render.
  """

  use ExUnit.Case, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Ctx
  alias Athanor.Fields

  # ─── default impl ──────────────────────────────────────────────────────

  defmodule StaticOnly do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "static_only", label: "S"}
    def fields, do: [{"title", :text, label: "Title"}]
  end

  describe "default resolve_fields/2 (no override)" do
    test "returns module.fields()" do
      assert StaticOnly.resolve_fields(%{}, %{}) == StaticOnly.fields()
    end

    test "ignores props + opts arguments" do
      assert StaticOnly.resolve_fields(%{"unrelated" => 7}, %{x: 1}) ==
               StaticOnly.fields()
    end
  end

  # ─── dynamic options based on sibling prop ─────────────────────────────

  defmodule DynamicOptions do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "dynamic_options", label: "D"}

    def fields,
      do: [
        {"num", :select, options: [{"2", "2"}, {"3", "3"}]},
        {"variant", :select, options: []}
      ]

    @impl Athanor.Component
    def resolve_fields(props, _opts) do
      num = props["num"]

      variant_options =
        case num do
          "2" -> [{"A", "a"}, {"B", "b"}]
          "3" -> [{"X", "x"}, {"Y", "y"}, {"Z", "z"}]
          _ -> []
        end

      Enum.map(fields(), fn
        {"variant", :select, opts} ->
          {"variant", :select, Keyword.put(opts, :options, variant_options)}

        f ->
          f
      end)
    end
  end

  describe "resolve_fields swaps options based on sibling props" do
    test "num=2 → variant select has A/B options" do
      html = render_fields(DynamicOptions, %{"num" => "2"})
      assert html =~ ~s(<option value="a")
      assert html =~ ~s(<option value="b")
      refute html =~ ~s(<option value="x")
    end

    test "num=3 → variant select has X/Y/Z options" do
      html = render_fields(DynamicOptions, %{"num" => "3"})
      assert html =~ ~s(<option value="x")
      assert html =~ ~s(<option value="y")
      assert html =~ ~s(<option value="z")
      refute html =~ ~s(<option value="a")
    end
  end

  # ─── conditional inclusion ─────────────────────────────────────────────

  defmodule ConditionalInclusion do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "cond_incl", label: "C"}
    def fields, do: [{"mode", :text, label: "Mode"}]

    @impl Athanor.Component
    def resolve_fields(props, _opts) do
      case props["mode"] do
        "advanced" ->
          fields() ++ [{"extra", :text, label: "Extra"}]

        _ ->
          fields()
      end
    end
  end

  describe "resolve_fields conditionally adds/removes fields" do
    test "mode=basic → only base fields shown" do
      html = render_fields(ConditionalInclusion, %{"mode" => "basic"})
      assert html =~ "Mode"
      refute html =~ "Extra"
    end

    test "mode=advanced → extra field appears" do
      html = render_fields(ConditionalInclusion, %{"mode" => "advanced"})
      assert html =~ "Mode"
      assert html =~ "Extra"
    end
  end

  # ─── field-type swap ────────────────────────────────────────────────────

  defmodule TypeSwap do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "type_swap", label: "T"}
    def fields, do: [{"body", :text, label: "Body"}]

    @impl Athanor.Component
    def resolve_fields(props, _opts) do
      if String.length(props["body"] || "") > 20 do
        [{"body", :textarea, label: "Body"}]
      else
        fields()
      end
    end
  end

  describe "resolve_fields swaps field type per content" do
    test "short body → text input" do
      html = render_fields(TypeSwap, %{"body" => "hi"})
      assert html =~ ~s(<input type="text")
      refute html =~ "<textarea"
    end

    test "long body → textarea" do
      html = render_fields(TypeSwap, %{"body" => String.duplicate("x", 30)})
      assert html =~ "<textarea"
    end
  end

  # ─── helper ────────────────────────────────────────────────────────────

  defp render_fields(module, props) do
    assigns = %{
      module: module,
      props: props,
      ctx: Ctx.new(),
      myself: nil,
      component_id: "test",
      on_custom_change: fn _k, _v -> :noop end
    }

    render_component(
      fn assigns ->
        ~H"""
        <Fields.render
          module={@module}
          props={@props}
          ctx={@ctx}
          myself={@myself}
          component_id={@component_id}
          on_custom_change={@on_custom_change}
        />
        """
      end,
      assigns
    )
  end
end
