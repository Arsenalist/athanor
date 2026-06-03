defmodule Athanor.Tree do
  @moduledoc """
  Pure-data tree operations over the page builder JSON shape.

  See `Athanor` for the project boundary contract. This module accepts and
  returns plain Elixir maps with string keys — no structs, no JSON encoding,
  no Phoenix/Ecto/Amplify dependencies.

  ## Shape

  A tree is a map with two well-known keys:

      %{
        "metadata" => map(),
        "content"  => [node, ...]
      }

  A node is a map:

      %{
        "id"    => "uuid-string",
        "type"  => "component-type-string",
        "props" => map()
      }

  A node MAY declare children via `node["props"]["zones"]` as a map of
  `%{zone_name => [child_node, ...]}`. Tree operations walk these zones
  automatically — no registry or callback required. Unknown keys at any
  level (top-level, props, metadata) are preserved on round-trip.
  """

  # --------------------------------------------------------------------------
  # from_json / to_json
  # --------------------------------------------------------------------------

  @doc """
  Normalize a decoded JSON value into the canonical tree shape, filling in
  `metadata` and `content` defaults and preserving every other key untouched.

  Accepts `nil` to mean "empty tree".

  ## Examples

      iex> Athanor.Tree.from_json(nil)
      %{"metadata" => %{}, "content" => []}

      iex> Athanor.Tree.from_json(%{"content" => []})
      %{"metadata" => %{}, "content" => []}

      iex> Athanor.Tree.from_json(%{"metadata" => %{"title" => "Hi"}})
      %{"metadata" => %{"title" => "Hi"}, "content" => []}
  """
  def from_json(nil), do: %{"metadata" => %{}, "content" => []}

  def from_json(map) when is_map(map) do
    map
    |> Map.put_new("metadata", %{})
    |> Map.put_new("content", [])
  end

  @doc """
  Serialize a tree back to a JSON-encodable map.

  Currently an identity function over the canonical shape — the tree is
  already a plain map. Exists as a paired entry point so callers can
  always pipe `from_json |> ... |> to_json` without thinking about
  whether the intermediate ops left the shape decoded or encoded.

  ## Examples

      iex> Athanor.Tree.to_json(%{"metadata" => %{}, "content" => []})
      %{"metadata" => %{}, "content" => []}
  """
  def to_json(tree) when is_map(tree), do: tree

  # --------------------------------------------------------------------------
  # walk / find
  # --------------------------------------------------------------------------

  @doc """
  Walk every node in the tree, invoking `fun.(node, acc)` for each.

  Visit order is pre-order: a parent node is visited before its children,
  and children are visited left-to-right within their containing list. Zone
  iteration order follows the underlying map's iteration order, which for
  Erlang maps is insertion-stable for small maps and undefined for large
  ones. In practice page builder zones are small.

  Children are discovered via the convention `node["props"]["zones"]`
  being a `%{zone_name => [child_node, ...]}` map. Nodes whose `zones` is
  absent or not a map are treated as leaves.

  ## Examples

      iex> tree = %{"metadata" => %{}, "content" => [
      ...>   %{"id" => "a", "type" => "text", "props" => %{}},
      ...>   %{"id" => "b", "type" => "text", "props" => %{}}
      ...> ]}
      iex> Athanor.Tree.walk(tree, [], fn n, acc -> [n["id"] | acc] end) |> Enum.reverse()
      ["a", "b"]
  """
  def walk(%{"content" => content}, acc, fun) when is_list(content) and is_function(fun, 2) do
    Enum.reduce(content, acc, &walk_node(&1, &2, fun))
  end

  def walk(tree, acc, fun) when is_map(tree) and is_function(fun, 2) do
    walk(from_json(tree), acc, fun)
  end

  defp walk_node(node, acc, fun) when is_map(node) do
    acc = fun.(node, acc)

    case get_in(node, ["props", "zones"]) do
      zones when is_map(zones) ->
        Enum.reduce(zones, acc, fn {_zone_name, children}, acc ->
          children
          |> List.wrap()
          |> Enum.reduce(acc, &walk_node(&1, &2, fun))
        end)

      _ ->
        acc
    end
  end

  @doc """
  Locate a node by its `id`, searching the root content and recursively
  through every `props["zones"]`.

  Returns `{:ok, node}` or `:error` when no node has the given id.

  ## Examples

      iex> tree = %{"metadata" => %{}, "content" => [
      ...>   %{"id" => "a", "type" => "text", "props" => %{}}
      ...> ]}
      iex> {:ok, node} = Athanor.Tree.find(tree, "a")
      iex> node["type"]
      "text"

      iex> Athanor.Tree.find(%{"metadata" => %{}, "content" => []}, "missing")
      :error
  """
  def find(tree, id) when is_map(tree) and is_binary(id) do
    walk(tree, :error, fn
      %{"id" => ^id} = node, :error -> {:ok, node}
      _node, acc -> acc
    end)
  end

  # --------------------------------------------------------------------------
  # insert
  # --------------------------------------------------------------------------

  @doc """
  Insert `node` into the tree at the given target.

  Targets:
  - `:root` — into the top-level `content` list
  - `{parent_id, zone_name}` — into a specific zone of a specific parent node

  Options:
  - `:at` — `:append` (default), `:prepend`, `{:index, n}`, `{:after, sibling_id}`

  Returns `{:ok, new_tree}` or `{:error, reason}` where reason is one of
  `:parent_not_found`, `:zone_not_found`, or `:sibling_not_found`.

  ## Examples

      iex> tree = %{"metadata" => %{}, "content" => [%{"id" => "a", "type" => "text", "props" => %{}}]}
      iex> n = %{"id" => "b", "type" => "text", "props" => %{}}
      iex> {:ok, t2} = Athanor.Tree.insert(tree, :root, n)
      iex> Enum.map(t2["content"], & &1["id"])
      ["a", "b"]
  """
  def insert(tree, target, node, opts \\ [])

  def insert(tree, :root, node, opts) when is_map(tree) and is_map(node) do
    case insert_into_list(tree["content"] || [], node, opts) do
      {:ok, new_list} -> {:ok, Map.put(tree, "content", new_list)}
      {:error, _} = err -> err
    end
  end

  def insert(tree, {parent_id, zone_name}, node, opts)
      when is_map(tree) and is_binary(parent_id) and is_binary(zone_name) and is_map(node) do
    update_zone(tree, parent_id, zone_name, fn list ->
      insert_into_list(list, node, opts)
    end)
  end

  defp insert_into_list(list, node, opts) do
    case Keyword.get(opts, :at, :append) do
      :append ->
        {:ok, list ++ [node]}

      :prepend ->
        {:ok, [node | list]}

      {:index, n} when is_integer(n) and n >= 0 ->
        {head, tail} = Enum.split(list, n)
        {:ok, head ++ [node] ++ tail}

      {:after, sibling_id} when is_binary(sibling_id) ->
        case Enum.find_index(list, &(&1["id"] == sibling_id)) do
          nil -> {:error, :sibling_not_found}
          idx -> insert_into_list(list, node, at: {:index, idx + 1})
        end
    end
  end

  # --------------------------------------------------------------------------
  # remove
  # --------------------------------------------------------------------------

  @doc """
  Remove the node with the given `id` from anywhere in the tree.

  Idempotent: removing an unknown id returns `{:ok, tree}` unchanged.

  ## Examples

      iex> tree = %{"metadata" => %{}, "content" => [%{"id" => "a", "type" => "text", "props" => %{}}]}
      iex> {:ok, t2} = Athanor.Tree.remove(tree, "a")
      iex> t2["content"]
      []

      iex> tree = %{"metadata" => %{}, "content" => [%{"id" => "a", "type" => "text", "props" => %{}}]}
      iex> {:ok, t2} = Athanor.Tree.remove(tree, "ghost")
      iex> t2 == tree
      true
  """
  def remove(tree, id) when is_map(tree) and is_binary(id) do
    new_content = remove_from_list(tree["content"] || [], id)
    {:ok, Map.put(tree, "content", new_content)}
  end

  defp remove_from_list(list, id) do
    list
    |> Enum.reject(&(&1["id"] == id))
    |> Enum.map(&remove_from_node(&1, id))
  end

  defp remove_from_node(node, id) do
    case get_in(node, ["props", "zones"]) do
      zones when is_map(zones) ->
        new_zones =
          Map.new(zones, fn {zname, children} ->
            {zname, remove_from_list(children, id)}
          end)

        put_in(node, ["props", "zones"], new_zones)

      _ ->
        node
    end
  end

  # --------------------------------------------------------------------------
  # update_props
  # --------------------------------------------------------------------------

  @doc """
  Update the `props` of the node identified by `id`.

  The third argument may be either a map (shallowly merged into the
  current props) or a function `(current_props -> new_props)`.

  Returns `{:ok, new_tree}` or `{:error, :not_found}` if the id is absent.

  ## Examples

      iex> tree = %{"metadata" => %{}, "content" => [
      ...>   %{"id" => "a", "type" => "text", "props" => %{"text" => "old"}}
      ...> ]}
      iex> {:ok, t2} = Athanor.Tree.update_props(tree, "a", %{"text" => "new"})
      iex> {:ok, node} = Athanor.Tree.find(t2, "a")
      iex> node["props"]["text"]
      "new"
  """
  def update_props(tree, id, props_or_fn)
      when is_map(tree) and is_binary(id) and (is_map(props_or_fn) or is_function(props_or_fn, 1)) do
    case update_props_in_list(tree["content"] || [], id, props_or_fn) do
      {:found, new_list} -> {:ok, Map.put(tree, "content", new_list)}
      :not_found -> {:error, :not_found}
    end
  end

  defp update_props_in_list(list, id, props_or_fn) do
    Enum.reduce_while(list, {:not_found, []}, fn node, {state, acc} ->
      case update_props_in_node(node, id, props_or_fn) do
        {:found, new_node} -> {:halt, {:done, [new_node | acc]}}
        :not_found -> {:cont, {state, [node | acc]}}
      end
    end)
    |> case do
      {:done, acc_reversed} ->
        matched_count = length(acc_reversed)
        tail = Enum.drop(list, matched_count)
        {:found, Enum.reverse(acc_reversed) ++ tail}

      {:not_found, _} ->
        :not_found
    end
  end

  defp update_props_in_node(%{"id" => id} = node, target_id, props_or_fn) when id == target_id do
    current = node["props"] || %{}

    new_props =
      case props_or_fn do
        m when is_map(m) -> Map.merge(current, m)
        f when is_function(f, 1) -> f.(current)
      end

    {:found, Map.put(node, "props", new_props)}
  end

  defp update_props_in_node(node, target_id, props_or_fn) do
    case get_in(node, ["props", "zones"]) do
      zones when is_map(zones) ->
        case update_props_in_zones(zones, target_id, props_or_fn) do
          {:found, new_zones} -> {:found, put_in(node, ["props", "zones"], new_zones)}
          :not_found -> :not_found
        end

      _ ->
        :not_found
    end
  end

  defp update_props_in_zones(zones, target_id, props_or_fn) do
    Enum.reduce_while(zones, {:not_found, %{}}, fn {zname, children}, {state, acc} ->
      case update_props_in_list(children, target_id, props_or_fn) do
        {:found, new_children} -> {:halt, {:done, Map.put(acc, zname, new_children), zname}}
        :not_found -> {:cont, {state, Map.put(acc, zname, children)}}
      end
    end)
    |> case do
      {:done, acc, matched_zname} ->
        remaining = zones |> Map.drop(Map.keys(acc)) |> Map.delete(matched_zname)
        {:found, Map.merge(acc, remaining)}

      {:not_found, _} ->
        :not_found
    end
  end

  # --------------------------------------------------------------------------
  # move / move_to
  # --------------------------------------------------------------------------

  @doc """
  Move the node with `node_id` from anywhere in the tree to `target`.

  `target` is `:root` (top-level content list) or `{parent_id, zone_name}`
  (a specific zone of a container node). `opts` accepts the same `:at`
  values as `insert/4` — `:append` (default), `:prepend`, `{:index, n}`,
  `{:after, sibling_id}`.

  Implemented as a find + remove + insert. Atomic: if the insert fails
  (e.g. `:parent_not_found`), the original tree is returned unchanged
  via the error tuple. Idempotent when the resulting position equals
  the original — returns the input tree byte-equal.

  ## Examples

      iex> tree = %{"metadata" => %{}, "content" => [
      ...>   %{"id" => "a", "type" => "text", "props" => %{}},
      ...>   %{"id" => "b", "type" => "text", "props" => %{}}
      ...> ]}
      iex> {:ok, t2} = Athanor.Tree.move_to(tree, "a", :root, at: {:index, 1})
      iex> Enum.map(t2["content"], & &1["id"])
      ["b", "a"]
  """
  def move_to(tree, node_id, target, opts \\ [])

  def move_to(tree, node_id, target, opts) when is_map(tree) and is_binary(node_id) do
    case find(tree, node_id) do
      :error ->
        {:error, :not_found}

      {:ok, node} ->
        # No-op shortcut: if the requested insert position is the node's
        # current position, return the tree unchanged. Cheap structural
        # check — at the root list only — because mid-tree shuffles
        # almost always change the resolved index.
        if same_position?(tree, node_id, target, opts) do
          {:ok, tree}
        else
          {:ok, without_node} = remove(tree, node_id)

          case insert(without_node, target, node, opts) do
            {:ok, _} = ok -> ok
            {:error, _} = err -> err
          end
        end
    end
  end

  defp same_position?(tree, node_id, :root, opts) do
    list = tree["content"] || []
    idx = Enum.find_index(list, &(&1["id"] == node_id))

    case {idx, Keyword.get(opts, :at, :append)} do
      {nil, _} -> false
      {i, {:index, j}} when i == j -> true
      {i, :append} when i == length(list) - 1 -> true
      {0, :prepend} -> true
      _ -> false
    end
  end

  defp same_position?(_tree, _node_id, _target, _opts), do: false

  @doc """
  Swap the node identified by `id` with its previous (`:up`) or next
  (`:down`) sibling inside the same containing list (root content or a
  specific zone). Moving past a boundary (first/last) is a no-op.

  Returns `{:ok, new_tree}` or `{:error, :not_found}` if the id is absent.

  ## Examples

      iex> tree = %{"metadata" => %{}, "content" => [
      ...>   %{"id" => "a", "type" => "text", "props" => %{}},
      ...>   %{"id" => "b", "type" => "text", "props" => %{}}
      ...> ]}
      iex> {:ok, t2} = Athanor.Tree.move(tree, "b", :up)
      iex> Enum.map(t2["content"], & &1["id"])
      ["b", "a"]
  """
  def move(tree, id, direction)
      when is_map(tree) and is_binary(id) and direction in [:up, :down] do
    case move_in_list(tree["content"] || [], id, direction) do
      {:found, new_list} ->
        {:ok, Map.put(tree, "content", new_list)}

      :not_found ->
        case move_in_descendants(tree["content"] || [], id, direction) do
          {:found, new_list} -> {:ok, Map.put(tree, "content", new_list)}
          :not_found -> {:error, :not_found}
        end
    end
  end

  defp move_in_list(list, id, direction) do
    case Enum.find_index(list, &(&1["id"] == id)) do
      nil ->
        :not_found

      idx ->
        new_idx =
          case direction do
            :up -> max(0, idx - 1)
            :down -> min(length(list) - 1, idx + 1)
          end

        if new_idx == idx do
          {:found, list}
        else
          {:found, swap_at(list, idx, new_idx)}
        end
    end
  end

  defp swap_at(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)

    list
    |> List.replace_at(i, b)
    |> List.replace_at(j, a)
  end

  # Recursively search every zone for a list containing `id` and apply
  # move_in_list there. Returns {:found, new_top_list} or :not_found.
  defp move_in_descendants(list, id, direction) do
    Enum.reduce_while(list, {:not_found, []}, fn node, {state, acc} ->
      case move_in_node(node, id, direction) do
        {:found, new_node} -> {:halt, {:done, [new_node | acc]}}
        :not_found -> {:cont, {state, [node | acc]}}
      end
    end)
    |> case do
      {:done, acc_reversed} ->
        matched_count = length(acc_reversed)
        tail = Enum.drop(list, matched_count)
        {:found, Enum.reverse(acc_reversed) ++ tail}

      {:not_found, _} ->
        :not_found
    end
  end

  defp move_in_node(node, id, direction) do
    case get_in(node, ["props", "zones"]) do
      zones when is_map(zones) ->
        case move_in_zones(zones, id, direction) do
          {:found, new_zones} -> {:found, put_in(node, ["props", "zones"], new_zones)}
          :not_found -> :not_found
        end

      _ ->
        :not_found
    end
  end

  defp move_in_zones(zones, id, direction) do
    Enum.reduce_while(zones, {:not_found, %{}}, fn {zname, children}, {state, acc} ->
      case move_in_list(children, id, direction) do
        {:found, new_children} ->
          {:halt, {:done, Map.put(acc, zname, new_children), zname}}

        :not_found ->
          case move_in_descendants(children, id, direction) do
            {:found, new_children} -> {:halt, {:done, Map.put(acc, zname, new_children), zname}}
            :not_found -> {:cont, {state, Map.put(acc, zname, children)}}
          end
      end
    end)
    |> case do
      {:done, acc, matched_zname} ->
        remaining = zones |> Map.drop(Map.keys(acc)) |> Map.delete(matched_zname)
        {:found, Map.merge(acc, remaining)}

      {:not_found, _} ->
        :not_found
    end
  end

  # --------------------------------------------------------------------------
  # Internal: locate a parent_id anywhere in the tree and update its named zone.
  # --------------------------------------------------------------------------
  #
  # `update_fn` is given the current zone list and must return either
  # `{:ok, new_list}` or `{:error, reason}`. The reason bubbles up unchanged.
  #
  # If parent_id is not found anywhere, returns `{:error, :parent_not_found}`.
  # If the parent is found but the zone_name is missing, returns
  # `{:error, :zone_not_found}`.

  defp update_zone(tree, parent_id, zone_name, update_fn) do
    case transform_list(tree["content"] || [], parent_id, zone_name, update_fn) do
      {:ok, new_content} -> {:ok, Map.put(tree, "content", new_content)}
      :not_found -> {:error, :parent_not_found}
      {:error, _} = err -> err
    end
  end

  # transform_list returns:
  #   {:ok, new_list}   — parent_id matched and zone updated inside this list (or below)
  #   :not_found         — parent_id not in this subtree
  #   {:error, reason}  — parent matched but zone missing / update returned error
  defp transform_list(list, parent_id, zone_name, update_fn) do
    Enum.reduce_while(list, {:not_found, []}, fn node, {state, acc} ->
      case transform_node(node, parent_id, zone_name, update_fn) do
        {:ok, new_node} -> {:halt, {:done, [new_node | acc]}}
        :not_found -> {:cont, {state, [node | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err ->
        err

      {:done, acc_reversed} ->
        # acc_reversed has the matched node at head, plus earlier-seen nodes after it.
        # We still need to append unprocessed tail (nodes after the match).
        matched_count = length(acc_reversed)
        tail = Enum.drop(list, matched_count)
        {:ok, Enum.reverse(acc_reversed) ++ tail}

      {:not_found, _acc} ->
        :not_found
    end
  end

  defp transform_node(%{"id" => id} = node, parent_id, zone_name, update_fn)
       when id == parent_id do
    zones = get_in(node, ["props", "zones"]) || %{}

    if Map.has_key?(zones, zone_name) do
      case update_fn.(Map.get(zones, zone_name, [])) do
        {:ok, new_list} ->
          {:ok, put_in(node, ["props", "zones"], Map.put(zones, zone_name, new_list))}

        {:error, _} = err ->
          err
      end
    else
      {:error, :zone_not_found}
    end
  end

  defp transform_node(node, parent_id, zone_name, update_fn) do
    case get_in(node, ["props", "zones"]) do
      zones when is_map(zones) ->
        case transform_zones(zones, parent_id, zone_name, update_fn) do
          {:ok, new_zones} -> {:ok, put_in(node, ["props", "zones"], new_zones)}
          :not_found -> :not_found
          {:error, _} = err -> err
        end

      _ ->
        :not_found
    end
  end

  defp transform_zones(zones, parent_id, zone_name, update_fn) do
    Enum.reduce_while(zones, {:not_found, %{}}, fn {zname, children}, {state, acc} ->
      case transform_list(children, parent_id, zone_name, update_fn) do
        {:ok, new_children} -> {:halt, {:done, Map.put(acc, zname, new_children), zname}}
        :not_found -> {:cont, {state, Map.put(acc, zname, children)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:error, _} = err ->
        err

      {:done, acc, matched_zname} ->
        # Merge in unprocessed zones (zones we never reduced over).
        remaining =
          zones
          |> Map.drop(Map.keys(acc))
          |> Map.delete(matched_zname)

        {:ok, Map.merge(acc, remaining)}

      {:not_found, _acc} ->
        :not_found
    end
  end
end
