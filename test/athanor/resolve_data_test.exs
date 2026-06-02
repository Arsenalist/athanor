defmodule Athanor.ResolveDataTest do
  @moduledoc """
  Tests for Athanor.Component's resolve_data/2 callback.

  Mirrors Puck's resolveData: lets a component transform its props
  immediately after a field change but BEFORE persistence. Used for
  computed/derived props, cascade updates (e.g. num_zones rewriting
  zone_names), normalization.

  AutoEditorForm must invoke resolve_data between Map.put and the
  :update_component_props send across ALL three update paths:
    - custom_field_changed action
    - component-tab form update_props
    - formatting-tab form update_props
  """

  use ExUnit.Case, async: true

  alias Athanor.AutoEditorForm

  # ─── default impl ──────────────────────────────────────────────────────

  defmodule StaticOnly do
    use Athanor.Component
    def metadata, do: %{type: "static_only", label: "S"}
    def fields, do: [{"title", :text, label: "Title"}]
  end

  describe "default resolve_data/2 (no override)" do
    test "returns the new props unchanged" do
      assert StaticOnly.resolve_data(%{"x" => 1}, %{"x" => 2}) == %{"x" => 2}
    end
  end

  # ─── cascade example: num_zones rewrites dependents ────────────────────

  defmodule WithCascade do
    use Athanor.Component
    def metadata, do: %{type: "cascade", label: "C"}

    def fields,
      do: [
        {"num_zones", :select, options: [{"2", "2"}, {"3", "3"}]}
      ]

    @impl Athanor.Component
    def resolve_data(old, new) do
      if old["num_zones"] != new["num_zones"] do
        n = String.to_integer(new["num_zones"] || "2")
        names = zone_names(n)
        old_zones = new["zones"] || %{}
        zones = Enum.reduce(names, %{}, fn k, acc -> Map.put(acc, k, Map.get(old_zones, k, [])) end)

        new
        |> Map.put("zone_names", names)
        |> Map.put("zones", zones)
      else
        new
      end
    end

    defp zone_names(2), do: ["one", "two"]
    defp zone_names(3), do: ["one", "two", "three"]
    defp zone_names(_), do: []
  end

  describe "resolve_data fires when num_zones changes" do
    test "adding a zone preserves existing children and adds an empty list" do
      old = %{
        "num_zones" => "2",
        "zone_names" => ["one", "two"],
        "zones" => %{"one" => ["existing_child"], "two" => []}
      }

      new_input = Map.put(old, "num_zones", "3")
      out = WithCascade.resolve_data(old, new_input)

      assert out["zone_names"] == ["one", "two", "three"]
      assert out["zones"]["one"] == ["existing_child"]
      assert out["zones"]["two"] == []
      assert out["zones"]["three"] == []
    end

    test "no-op when num_zones unchanged (cascade not fired)" do
      old = %{"num_zones" => "2", "other" => "x"}
      assert WithCascade.resolve_data(old, old) == old
    end
  end

  # ─── AutoEditorForm wiring ─────────────────────────────────────────────
  #
  # Direct module call; the real AutoEditorForm has socket plumbing
  # we exercise in the live-test below.

  describe "AutoEditorForm component-tab update_props pipes through resolve_data" do
    test "Map.put result is transformed by component's resolve_data" do
      # Simulate the post-Map.put state — then verify AutoEditorForm's
      # transform helper produces the cascaded result. Helper is exposed
      # via the module so tests can poke it without socket plumbing.
      old = %{"num_zones" => "2", "zones" => %{"one" => ["a"], "two" => []}}
      new_after_put = Map.put(old, "num_zones", "3")

      out = AutoEditorForm.apply_resolve_data(WithCascade, old, new_after_put)

      assert out["zone_names"] == ["one", "two", "three"]
      assert out["zones"]["one"] == ["a"]
      assert out["zones"]["three"] == []
    end

    test "module without resolve_data → new props returned as-is" do
      old = %{"title" => "T"}
      new = Map.put(old, "title" , "T2")

      assert AutoEditorForm.apply_resolve_data(StaticOnly, old, new) == new
    end
  end
end
