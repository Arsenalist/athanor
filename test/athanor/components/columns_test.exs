defmodule Athanor.Components.ColumnsTest do
  @moduledoc """
  Tests for the library-native Columns container.

  Storage shape (matches Puck-style explicit storage + Amplify legacy):
    zone_names:         ["one", "two", ...]      (2..4 strings)
    zones:              %{"one" => [nodes], ...}
    num_zones:          "2" | "3" | "4"          (string for select)
    vertical_align:     "top" | "center" | "bottom" | "stretch"
    width_distribution: "equal" | "66-33" | etc. (depends on num_zones)
  """

  use ExUnit.Case, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.AutoEditorForm
  alias Athanor.Components.Columns
  alias Athanor.Ctx

  # ─── Athanor.Component contract ────────────────────────────────────────

  describe "metadata" do
    test "has type/label/icon" do
      meta = Columns.metadata()
      assert meta.type == "columns"
      assert meta.label == "Columns"
      assert meta.icon == "fa-columns"
    end
  end

  describe "default_props" do
    test "seeds 2 equal-width zones with top alignment" do
      d = Columns.default_props()
      assert d["num_zones"] == "2"
      assert d["zone_names"] == ["one", "two"]
      assert d["zones"] == %{"one" => [], "two" => []}
      assert d["vertical_align"] == "top"
      assert d["width_distribution"] == "equal"
    end
  end

  describe "validate" do
    test "ok for 2..4 zones" do
      assert Columns.validate(%{"zone_names" => ["a", "b"]}) == :ok
      assert Columns.validate(%{"zone_names" => ["a", "b", "c", "d"]}) == :ok
    end

    test "error for empty / 1 / 5+ zones" do
      assert {:error, _} = Columns.validate(%{"zone_names" => []})
      assert {:error, _} = Columns.validate(%{"zone_names" => ["a"]})
      assert {:error, _} = Columns.validate(%{"zone_names" => ~w(a b c d e)})
    end

    test "error when zone_names absent / not a list" do
      assert {:error, _} = Columns.validate(%{})
      assert {:error, _} = Columns.validate(%{"zone_names" => "x"})
    end
  end

  describe "child_zones/1" do
    test "returns the zones map" do
      node = %{
        "type" => "columns",
        "props" => %{"zones" => %{"one" => [%{"id" => "n1"}], "two" => []}}
      }

      assert Columns.child_zones(node) == %{
               "one" => [%{"id" => "n1"}],
               "two" => []
             }
    end

    test "returns empty map when zones absent" do
      assert Columns.child_zones(%{"type" => "columns", "props" => %{}}) == %{}
    end
  end

  # ─── fields + resolve_fields ───────────────────────────────────────────

  describe "fields/0" do
    test "declares num_zones, vertical_align, width_distribution" do
      fields = Columns.fields()
      keys = Enum.map(fields, fn {k, _t, _o} -> k end)
      assert keys == ["num_zones", "vertical_align", "width_distribution"]
    end

    test "num_zones select offers 2/3/4" do
      [{"num_zones", :select, opts} | _] = Columns.fields()
      values = Enum.map(opts[:options], fn {_l, v} -> v end)
      assert values == ["2", "3", "4"]
    end
  end

  describe "resolve_fields/2 — width_distribution options per num_zones" do
    test "num_zones=2 → 5 distribution options" do
      fields = Columns.resolve_fields(%{"num_zones" => "2"}, %{})
      {_, _, wd_opts} = Enum.find(fields, fn {k, _, _} -> k == "width_distribution" end)
      assert length(wd_opts[:options]) == 5
      values = Enum.map(wd_opts[:options], fn {_l, v} -> v end)
      assert "equal" in values
      assert "66-33" in values
    end

    test "num_zones=3 → 4 distribution options" do
      fields = Columns.resolve_fields(%{"num_zones" => "3"}, %{})
      {_, _, wd_opts} = Enum.find(fields, fn {k, _, _} -> k == "width_distribution" end)
      assert length(wd_opts[:options]) == 4
    end

    test "num_zones=4 → 1 distribution option (equal only)" do
      fields = Columns.resolve_fields(%{"num_zones" => "4"}, %{})
      {_, _, wd_opts} = Enum.find(fields, fn {k, _, _} -> k == "width_distribution" end)
      assert length(wd_opts[:options]) == 1
      assert wd_opts[:options] == [{"Equal (25/25/25/25)", "equal"}]
    end

    test "missing num_zones → falls back to 2-zone options" do
      fields = Columns.resolve_fields(%{}, %{})
      {_, _, wd_opts} = Enum.find(fields, fn {k, _, _} -> k == "width_distribution" end)
      assert length(wd_opts[:options]) == 5
    end
  end

  # ─── resolve_data cascade ──────────────────────────────────────────────

  describe "resolve_data/2 — num_zones cascade" do
    test "no-op when num_zones unchanged" do
      old = %{
        "num_zones" => "2",
        "zone_names" => ["one", "two"],
        "zones" => %{"one" => ["x"], "two" => []},
        "width_distribution" => "66-33"
      }

      assert Columns.resolve_data(old, old) == old
    end

    test "num_zones 2→3 rebuilds zone_names + preserves child content + adds empty new zone" do
      old = %{
        "num_zones" => "2",
        "zone_names" => ["one", "two"],
        "zones" => %{"one" => ["existing"], "two" => ["other"]}
      }

      new = Map.put(old, "num_zones", "3")
      out = Columns.resolve_data(old, new)

      assert out["zone_names"] == ["one", "two", "three"]
      assert out["zones"]["one"] == ["existing"]
      assert out["zones"]["two"] == ["other"]
      assert out["zones"]["three"] == []
    end

    test "num_zones 3→2 drops the third zone (children lost — accept tradeoff)" do
      old = %{
        "num_zones" => "3",
        "zone_names" => ["one", "two", "three"],
        "zones" => %{"one" => ["a"], "two" => ["b"], "three" => ["c"]}
      }

      new = Map.put(old, "num_zones", "2")
      out = Columns.resolve_data(old, new)

      assert out["zone_names"] == ["one", "two"]
      assert out["zones"] == %{"one" => ["a"], "two" => ["b"]}
    end

    test "num_zones change resets width_distribution to equal" do
      old = %{
        "num_zones" => "2",
        "zone_names" => ["one", "two"],
        "zones" => %{"one" => [], "two" => []},
        "width_distribution" => "66-33"
      }

      new = Map.put(old, "num_zones", "3")
      out = Columns.resolve_data(old, new)
      assert out["width_distribution"] == "equal"
    end

    test "width_distribution preserved when num_zones unchanged" do
      old = %{
        "num_zones" => "3",
        "zone_names" => ["one", "two", "three"],
        "zones" => %{"one" => [], "two" => [], "three" => []},
        "width_distribution" => "25-50-25"
      }

      new = Map.put(old, "vertical_align", "center")
      out = Columns.resolve_data(old, new)
      assert out["width_distribution"] == "25-50-25"
    end
  end

  # ─── render(:live) ─────────────────────────────────────────────────────

  describe "render(:live, node, ctx) — storefront (edit_mode? = false)" do
    test "renders flex container with zone divs and no edit chrome" do
      node = %{
        "id" => "c1",
        "type" => "columns",
        "props" => %{
          "num_zones" => "2",
          "zone_names" => ["one", "two"],
          "zones" => %{"one" => [], "two" => []},
          "vertical_align" => "center",
          "width_distribution" => "equal"
        }
      }

      html = render_live(node, Ctx.new(edit_mode?: false))
      assert html =~ "items-center"
      assert html =~ "w-1/2"
      refute html =~ "border-dashed"
      refute html =~ "+ Add Component"
    end
  end

  describe "render(:live, node, ctx) — editor canvas (edit_mode? = true)" do
    test "renders dashed-border zone chrome + per-zone Add button" do
      cb = fn zone -> Phoenix.LiveView.JS.push("show_zone_picker", value: %{zone: zone}) end

      ctx =
        Ctx.new(
          edit_mode?: true,
          add_component_callback: cb
        )

      node = %{
        "id" => "c1",
        "type" => "columns",
        "props" => %{
          "num_zones" => "2",
          "zone_names" => ["one", "two"],
          "zones" => %{"one" => [], "two" => []},
          "vertical_align" => "top",
          "width_distribution" => "equal"
        }
      }

      html = render_live(node, ctx)
      assert html =~ "border-dashed"
      assert html =~ "Add Component"
      # Both zones get their own button
      assert html |> String.split("Add Component") |> length() == 3
    end

    test "no add button when callback is nil" do
      ctx = Ctx.new(edit_mode?: true, add_component_callback: nil)

      node = %{
        "id" => "c1",
        "type" => "columns",
        "props" => %{
          "num_zones" => "2",
          "zone_names" => ["one", "two"],
          "zones" => %{"one" => [], "two" => []}
        }
      }

      html = render_live(node, ctx)
      refute html =~ "Add Component"
    end
  end

  # ─── AutoEditorForm integration ───────────────────────────────────────

  describe "apply_resolve_data via AutoEditorForm helper" do
    test "going through the AutoEditorForm cascade preserves zone content" do
      old = %{
        "num_zones" => "2",
        "zone_names" => ["one", "two"],
        "zones" => %{"one" => ["child1"], "two" => []}
      }

      new_after_put = Map.put(old, "num_zones", "3")
      out = AutoEditorForm.apply_resolve_data(Columns, old, new_after_put)

      assert out["zone_names"] == ["one", "two", "three"]
      assert out["zones"]["one"] == ["child1"]
      assert out["zones"]["three"] == []
    end
  end

  # ─── helper ────────────────────────────────────────────────────────────

  defp render_live(node, ctx) do
    assigns = %{rendered: Columns.render(:live, node, ctx)}

    render_component(
      fn assigns ->
        ~H"{@rendered}"
      end,
      assigns
    )
  end
end
