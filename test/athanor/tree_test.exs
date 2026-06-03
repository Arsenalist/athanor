defmodule Athanor.TreeTest do
  use ExUnit.Case, async: true

  import Athanor.FixtureHelpers

  alias Athanor.Tree

  doctest Athanor.Tree

  describe "fixture loading sanity" do
    test "load_fixture/1 reads text_only.json" do
      fixture = load_fixture("text_only")
      assert is_map(fixture)
      assert is_list(fixture["content"])
    end

    test "all_fixture_paths/0 finds the seeded fixtures" do
      paths = all_fixture_paths()
      basenames = Enum.map(paths, &Path.basename(&1, ".json"))

      assert "text_only" in basenames
      assert "with_image" in basenames
      assert "single_column" in basenames
      assert "two_columns_simple" in basenames
      assert "nested_columns" in basenames
      assert "legacy_metadata" in basenames
    end
  end

  describe "from_json/1" do
    test "returns the same map for a minimal tree (text_only)" do
      fixture = load_fixture("text_only")
      assert Tree.from_json(fixture) == fixture
    end

    test "nil input returns the empty-tree shape" do
      assert Tree.from_json(nil) == %{"metadata" => %{}, "content" => []}
    end

    test "missing metadata is filled with an empty map" do
      input = %{"content" => []}
      assert Tree.from_json(input) == %{"metadata" => %{}, "content" => []}
    end

    test "missing content is filled with an empty list" do
      input = %{"metadata" => %{"title" => "Hi"}}
      assert Tree.from_json(input) == %{"metadata" => %{"title" => "Hi"}, "content" => []}
    end

    test "preserves unknown top-level keys" do
      input = %{
        "metadata" => %{},
        "content" => [],
        "version" => 1,
        "future_thing" => %{"a" => 1}
      }

      result = Tree.from_json(input)
      assert result["version"] == 1
      assert result["future_thing"] == %{"a" => 1}
    end
  end

  describe "to_json/1" do
    test "is the inverse of from_json for text_only fixture" do
      fixture = load_fixture("text_only")
      assert fixture |> Tree.from_json() |> Tree.to_json() == fixture
    end

    test "round-trips the empty tree" do
      assert nil |> Tree.from_json() |> Tree.to_json() == %{
               "metadata" => %{},
               "content" => []
             }
    end
  end

  describe "round-trip identity (snapshot suite)" do
    for path <- Athanor.FixtureHelpers.all_fixture_paths() do
      name = Path.basename(path, ".json")

      test "fixture #{name} round-trips byte-identically" do
        decoded = load_fixture(unquote(name))
        roundtripped = decoded |> Tree.from_json() |> Tree.to_json()

        # Compare via canonical re-encoding so map key order doesn't matter.
        assert canonicalize(roundtripped) == canonicalize(decoded)
      end
    end
  end

  describe "update_props/3" do
    test "merges a map into existing props at root" do
      tree = load_fixture("text_only")
      id = "00000000-0000-0000-0000-000000000001"

      {:ok, t2} = Tree.update_props(tree, id, %{"text" => "<p>updated</p>", "extra" => true})
      {:ok, node} = Tree.find(t2, id)

      assert node["props"]["text"] == "<p>updated</p>"
      assert node["props"]["extra"] == true
    end

    test "accepts a function and uses returned map" do
      tree = load_fixture("text_only")
      id = "00000000-0000-0000-0000-000000000001"

      {:ok, t2} = Tree.update_props(tree, id, fn props -> Map.put(props, "count", 7) end)
      {:ok, node} = Tree.find(t2, id)

      assert node["props"]["count"] == 7
      # Existing keys preserved when the function only adds.
      assert node["props"]["text"] == "<p>Welcome to our event series.</p>"
    end

    test "updates a zone-nested node" do
      tree = load_fixture("nested_columns")
      id = "00000000-0000-0000-0000-000000000046"

      {:ok, t2} = Tree.update_props(tree, id, %{"title" => "Renamed hero"})
      {:ok, node} = Tree.find(t2, id)

      assert node["props"]["title"] == "Renamed hero"
      # Other props preserved.
      assert node["props"]["text"] == "very nested"
    end

    test "unknown id returns {:error, :not_found}" do
      tree = load_fixture("text_only")
      assert Tree.update_props(tree, "ghost", %{}) == {:error, :not_found}
    end

    test "original tree props remain unchanged after update (no shared refs)" do
      tree = load_fixture("text_only")
      id = "00000000-0000-0000-0000-000000000001"
      original_props = elem(Tree.find(tree, id), 1)["props"]

      {:ok, _t2} = Tree.update_props(tree, id, %{"text" => "mutated"})

      {:ok, still_original} = Tree.find(tree, id)
      assert still_original["props"] == original_props
    end
  end

  describe "move/3" do
    test ":up swaps with previous sibling at root" do
      tree = make_root_tree(~w(a b c))
      {:ok, t2} = Tree.move(tree, "b", :up)
      assert ids_at_root(t2) == ~w(b a c)
    end

    test ":down swaps with next sibling at root" do
      tree = make_root_tree(~w(a b c))
      {:ok, t2} = Tree.move(tree, "b", :down)
      assert ids_at_root(t2) == ~w(a c b)
    end

    test ":up at first position is a no-op" do
      tree = make_root_tree(~w(a b c))
      {:ok, t2} = Tree.move(tree, "a", :up)
      assert ids_at_root(t2) == ~w(a b c)
    end

    test ":down at last position is a no-op" do
      tree = make_root_tree(~w(a b c))
      {:ok, t2} = Tree.move(tree, "c", :down)
      assert ids_at_root(t2) == ~w(a b c)
    end

    test "sole child is a no-op in either direction" do
      tree = make_root_tree(~w(only))
      assert {:ok, ^tree} = Tree.move(tree, "only", :up)
      assert {:ok, ^tree} = Tree.move(tree, "only", :down)
    end

    test "within a zone swaps siblings inside that zone" do
      tree = load_fixture("two_columns_simple")
      {:ok, t2} = Tree.move(tree, "00000000-0000-0000-0000-000000000031", :down)

      {:ok, cols} = Tree.find(t2, "00000000-0000-0000-0000-000000000030")
      ids = Enum.map(cols["props"]["zones"]["one"], & &1["id"])

      assert ids == [
               "00000000-0000-0000-0000-000000000032",
               "00000000-0000-0000-0000-000000000031"
             ]

      # The right zone is untouched.
      right_ids = Enum.map(cols["props"]["zones"]["two"], & &1["id"])
      assert right_ids == ["00000000-0000-0000-0000-000000000033"]
    end

    test "deep nested zone move" do
      tree = load_fixture("nested_columns")
      {:ok, t2} = Tree.move(tree, "00000000-0000-0000-0000-000000000044", :down)

      {:ok, inner} = Tree.find(t2, "00000000-0000-0000-0000-000000000043")
      # Inner zone "one" had only one child (44) so move down is no-op.
      # Verify nothing went sideways into zone "two" or "three".
      assert Enum.map(inner["props"]["zones"]["one"], & &1["id"]) == [
               "00000000-0000-0000-0000-000000000044"
             ]
    end

    test "unknown id returns {:error, :not_found}" do
      tree = load_fixture("text_only")
      assert Tree.move(tree, "ghost", :up) == {:error, :not_found}
    end
  end

  defp make_root_tree(ids) do
    %{
      "metadata" => %{},
      "content" => Enum.map(ids, fn id -> %{"id" => id, "type" => "text", "props" => %{}} end)
    }
  end

  defp ids_at_root(tree), do: Enum.map(tree["content"], & &1["id"])

  describe "remove/2" do
    test "removes a root-level node" do
      tree = load_fixture("text_only")
      {:ok, t2} = Tree.remove(tree, "00000000-0000-0000-0000-000000000001")
      assert length(t2["content"]) == 1
      assert hd(t2["content"])["id"] == "00000000-0000-0000-0000-000000000002"
    end

    test "removes a zone-nested node" do
      tree = load_fixture("two_columns_simple")
      {:ok, t2} = Tree.remove(tree, "00000000-0000-0000-0000-000000000032")

      {:ok, cols} = Tree.find(t2, "00000000-0000-0000-0000-000000000030")
      ids = Enum.map(cols["props"]["zones"]["one"], & &1["id"])
      assert ids == ["00000000-0000-0000-0000-000000000031"]
    end

    test "removes a deeply nested node" do
      tree = load_fixture("nested_columns")
      {:ok, t2} = Tree.remove(tree, "00000000-0000-0000-0000-000000000046")

      {:ok, inner} = Tree.find(t2, "00000000-0000-0000-0000-000000000043")
      assert inner["props"]["zones"]["three"] == []
    end

    test "with unknown id is idempotent" do
      tree = load_fixture("text_only")
      assert Tree.remove(tree, "ghost") == {:ok, tree}
    end

    test "insert + remove is identity for a fresh node" do
      tree = load_fixture("text_only")
      n = %{"id" => "fresh-id", "type" => "text", "props" => %{"text" => "x"}}

      {:ok, t2} = Tree.insert(tree, :root, n)
      {:ok, t3} = Tree.remove(t2, "fresh-id")
      assert t3 == tree
    end

    test "insert + remove identity inside a zone" do
      tree = load_fixture("single_column")
      n = %{"id" => "z-fresh", "type" => "text", "props" => %{}}

      {:ok, t2} = Tree.insert(tree, {"00000000-0000-0000-0000-000000000020", "two"}, n)
      {:ok, t3} = Tree.remove(t2, "z-fresh")
      assert t3 == tree
    end
  end

  describe "insert/3,4 at :root" do
    setup do
      %{
        tree: load_fixture("text_only"),
        n: %{"id" => "new", "type" => "text", "props" => %{"text" => "<p>n</p>"}}
      }
    end

    test "appends by default", %{tree: tree, n: n} do
      {:ok, t2} = Tree.insert(tree, :root, n)
      assert List.last(t2["content"])["id"] == "new"
      assert length(t2["content"]) == 3
    end

    test "prepends with at: :prepend", %{tree: tree, n: n} do
      {:ok, t2} = Tree.insert(tree, :root, n, at: :prepend)
      assert hd(t2["content"])["id"] == "new"
    end

    test "inserts at specific index", %{tree: tree, n: n} do
      {:ok, t2} = Tree.insert(tree, :root, n, at: {:index, 1})
      assert Enum.at(t2["content"], 1)["id"] == "new"
      assert Enum.at(t2["content"], 0)["id"] == "00000000-0000-0000-0000-000000000001"
      assert Enum.at(t2["content"], 2)["id"] == "00000000-0000-0000-0000-000000000002"
    end

    test "inserts after a sibling id", %{tree: tree, n: n} do
      {:ok, t2} =
        Tree.insert(tree, :root, n, at: {:after, "00000000-0000-0000-0000-000000000001"})

      assert Enum.at(t2["content"], 1)["id"] == "new"
    end

    test "returns {:error, :sibling_not_found} when :after sibling missing", %{tree: tree, n: n} do
      assert Tree.insert(tree, :root, n, at: {:after, "ghost"}) ==
               {:error, :sibling_not_found}
    end
  end

  describe "insert/3,4 into zones" do
    test "appends into an empty zone" do
      tree = load_fixture("single_column")
      n = %{"id" => "z-new", "type" => "text", "props" => %{"text" => "x"}}

      {:ok, t2} = Tree.insert(tree, {"00000000-0000-0000-0000-000000000020", "two"}, n)

      cols = hd(t2["content"])
      assert length(cols["props"]["zones"]["two"]) == 1
      assert hd(cols["props"]["zones"]["two"])["id"] == "z-new"
      # Other zone untouched.
      assert length(cols["props"]["zones"]["one"]) == 1
    end

    test "inserts into deeply nested zone" do
      tree = load_fixture("nested_columns")
      n = %{"id" => "deep-new", "type" => "text", "props" => %{"text" => "x"}}

      {:ok, t2} = Tree.insert(tree, {"00000000-0000-0000-0000-000000000043", "two"}, n)

      {:ok, parent} = Tree.find(t2, "00000000-0000-0000-0000-000000000043")
      ids = Enum.map(parent["props"]["zones"]["two"], & &1["id"])
      assert "deep-new" in ids
      # Original sibling still present.
      assert "00000000-0000-0000-0000-000000000045" in ids
    end

    test "returns {:error, :parent_not_found} for unknown parent_id" do
      tree = load_fixture("text_only")
      n = %{"id" => "x", "type" => "text", "props" => %{}}
      assert Tree.insert(tree, {"ghost", "one"}, n) == {:error, :parent_not_found}
    end

    test "returns {:error, :zone_not_found} for unknown zone" do
      tree = load_fixture("single_column")
      n = %{"id" => "x", "type" => "text", "props" => %{}}

      assert Tree.insert(tree, {"00000000-0000-0000-0000-000000000020", "three"}, n) ==
               {:error, :zone_not_found}
    end
  end

  describe "move_to/3,4" do
    test "moves a root node to a different root index" do
      tree = load_fixture("text_only")

      {:ok, t2} =
        Tree.move_to(tree, "00000000-0000-0000-0000-000000000001", :root, at: {:index, 1})

      ids = Enum.map(t2["content"], & &1["id"])

      assert ids == [
               "00000000-0000-0000-0000-000000000002",
               "00000000-0000-0000-0000-000000000001"
             ]
    end

    test "moves a root node into a zone" do
      tree = load_fixture("single_column")
      # tree has a Columns at root with id ...20, and one root-level sibling outside? load fixture
      # to see; single_column has one Columns root with zone "one" populated. Move it onto its own
      # zone "two" — a real reparent.
      n = %{"id" => "rooty", "type" => "text", "props" => %{"text" => "x"}}
      {:ok, with_root} = Tree.insert(tree, :root, n)

      {:ok, t2} =
        Tree.move_to(with_root, "rooty", {"00000000-0000-0000-0000-000000000020", "two"})

      {:ok, parent} = Tree.find(t2, "00000000-0000-0000-0000-000000000020")
      assert Enum.any?(parent["props"]["zones"]["two"], &(&1["id"] == "rooty"))
      refute Enum.any?(t2["content"], &(&1["id"] == "rooty"))
    end

    test "moves a zone child to root" do
      tree = load_fixture("single_column")
      # The single populated zone "one" has one child — move it to root.
      {:ok, parent_before} = Tree.find(tree, "00000000-0000-0000-0000-000000000020")
      [child | _] = parent_before["props"]["zones"]["one"]
      child_id = child["id"]

      {:ok, t2} = Tree.move_to(tree, child_id, :root)

      assert Enum.any?(t2["content"], &(&1["id"] == child_id))
      {:ok, parent_after} = Tree.find(t2, "00000000-0000-0000-0000-000000000020")
      refute Enum.any?(parent_after["props"]["zones"]["one"], &(&1["id"] == child_id))
    end

    test "moves a node between zones of the same parent" do
      tree = load_fixture("single_column")
      {:ok, parent_before} = Tree.find(tree, "00000000-0000-0000-0000-000000000020")
      [child | _] = parent_before["props"]["zones"]["one"]
      child_id = child["id"]

      {:ok, t2} =
        Tree.move_to(tree, child_id, {"00000000-0000-0000-0000-000000000020", "two"})

      {:ok, parent_after} = Tree.find(t2, "00000000-0000-0000-0000-000000000020")
      assert Enum.any?(parent_after["props"]["zones"]["two"], &(&1["id"] == child_id))
      refute Enum.any?(parent_after["props"]["zones"]["one"], &(&1["id"] == child_id))
    end

    test "no-op for same-position move" do
      tree = load_fixture("text_only")
      first_id = "00000000-0000-0000-0000-000000000001"

      {:ok, t2} = Tree.move_to(tree, first_id, :root, at: {:index, 0})
      assert t2 == tree
    end

    test "returns {:error, :not_found} for unknown node_id" do
      tree = load_fixture("text_only")
      assert Tree.move_to(tree, "ghost", :root) == {:error, :not_found}
    end

    test "respects at: opt when inserting at root" do
      tree = load_fixture("text_only")

      {:ok, t2} =
        Tree.move_to(tree, "00000000-0000-0000-0000-000000000002", :root, at: :prepend)

      assert hd(t2["content"])["id"] == "00000000-0000-0000-0000-000000000002"
    end

    test "returns {:error, :parent_not_found} for unknown target parent" do
      tree = load_fixture("text_only")

      assert Tree.move_to(tree, "00000000-0000-0000-0000-000000000001", {"ghost", "one"}) ==
               {:error, :parent_not_found}
    end
  end

  describe "find/2" do
    test "returns {:ok, node} for root-level id" do
      tree = load_fixture("text_only")
      {:ok, node} = Tree.find(tree, "00000000-0000-0000-0000-000000000001")
      assert node["type"] == "text"
      assert node["props"]["text"] == "<p>Welcome to our event series.</p>"
    end

    test "returns {:ok, node} for zone-nested id" do
      tree = load_fixture("nested_columns")
      {:ok, node} = Tree.find(tree, "00000000-0000-0000-0000-000000000046")
      assert node["type"] == "hero"
      assert node["props"]["title"] == "Deep hero"
    end

    test "returns :error for unknown id" do
      tree = load_fixture("text_only")
      assert Tree.find(tree, "does-not-exist") == :error
    end
  end

  describe "walk/3" do
    test "visits every node in a flat tree" do
      tree = load_fixture("text_only")
      ids = Tree.walk(tree, [], fn node, acc -> [node["id"] | acc] end) |> Enum.reverse()

      assert ids == [
               "00000000-0000-0000-0000-000000000001",
               "00000000-0000-0000-0000-000000000002"
             ]
    end

    test "descends into props[\"zones\"]" do
      tree = load_fixture("two_columns_simple")
      ids = Tree.walk(tree, [], fn node, acc -> [node["id"] | acc] end) |> Enum.reverse()

      assert "00000000-0000-0000-0000-000000000030" in ids
      assert "00000000-0000-0000-0000-000000000031" in ids
      assert "00000000-0000-0000-0000-000000000032" in ids
      assert "00000000-0000-0000-0000-000000000033" in ids
      assert length(ids) == 4
    end

    test "handles deeply nested zones (nested_columns)" do
      tree = load_fixture("nested_columns")
      ids = Tree.walk(tree, [], fn node, acc -> [node["id"] | acc] end) |> Enum.reverse()

      # Root text (40) + outer columns (41) + outer left text (42)
      # + inner columns (43) + 3 inner children (44, 45, 46) = 7
      assert length(ids) == 7
      assert "00000000-0000-0000-0000-000000000040" in ids
      assert "00000000-0000-0000-0000-000000000046" in ids
    end

    test "visit order: parent before children, left-to-right within content" do
      tree = load_fixture("nested_columns")
      ids = Tree.walk(tree, [], fn node, acc -> [node["id"] | acc] end) |> Enum.reverse()

      # Root text comes before outer columns (left-to-right in content).
      assert index_of(ids, "00000000-0000-0000-0000-000000000040") <
               index_of(ids, "00000000-0000-0000-0000-000000000041")

      # Outer columns visited before its children.
      assert index_of(ids, "00000000-0000-0000-0000-000000000041") <
               index_of(ids, "00000000-0000-0000-0000-000000000042")

      # Inner columns visited before its deepest leaf.
      assert index_of(ids, "00000000-0000-0000-0000-000000000043") <
               index_of(ids, "00000000-0000-0000-0000-000000000046")
    end

    test "skips nodes whose props[\"zones\"] is absent" do
      tree = load_fixture("with_image")
      # Hero + Image, no nesting.
      ids = Tree.walk(tree, [], fn node, acc -> [node["id"] | acc] end) |> Enum.reverse()
      assert length(ids) == 2
    end

    test "ignores props[\"zones\"] when value is not a map" do
      # Edge case: a node with a stray non-map zones key shouldn't crash the walker.
      tree = %{
        "metadata" => %{},
        "content" => [
          %{
            "id" => "x",
            "type" => "text",
            "props" => %{"zones" => "not a map"}
          }
        ]
      }

      ids = Tree.walk(tree, [], fn node, acc -> [node["id"] | acc] end)
      assert ids == ["x"]
    end

    test "count matches independent recursive count (property-ish)" do
      for name <-
            ~w(text_only with_image single_column two_columns_simple nested_columns legacy_metadata) do
        tree = load_fixture(name)
        walked = Tree.walk(tree, 0, fn _node, acc -> acc + 1 end)
        expected = naive_count(tree)
        assert walked == expected, "fixture #{name}: walked=#{walked} expected=#{expected}"
      end
    end
  end

  defp naive_count(%{"content" => content}), do: Enum.sum(Enum.map(content, &naive_count_node/1))

  defp naive_count_node(node) do
    zones = get_in(node, ["props", "zones"])

    child_count =
      case zones do
        m when is_map(m) ->
          m
          |> Map.values()
          |> List.flatten()
          |> Enum.map(&naive_count_node/1)
          |> Enum.sum()

        _ ->
          0
      end

    1 + child_count
  end

  defp index_of(list, item), do: Enum.find_index(list, &(&1 == item))

  # Recursively sort map keys so two maps with the same content but different
  # iteration order serialize identically.
  defp canonicalize(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, canonicalize(v)} end)
    |> Enum.sort_by(fn {k, _} -> k end)
  end

  defp canonicalize(list) when is_list(list), do: Enum.map(list, &canonicalize/1)
  defp canonicalize(other), do: other
end
