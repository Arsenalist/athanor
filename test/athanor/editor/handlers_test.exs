defmodule Athanor.Editor.HandlersTest do
  @moduledoc """
  Tests for `Athanor.Editor.Live` event handlers that mutate the content
  tree or invoke the consumer's save callback.

  Covers the gaps not exercised by `live_test.exs`:
  add_component, remove_component, move_component, add_component_to_zone,
  save → success/error toast.
  """

  use ExUnit.Case, async: false
  use Phoenix.Component

  alias Athanor.Editor.Live, as: EditorLive
  alias Athanor.Editor.State

  # ─── fake consumer modules ─────────────────────────────────────────────

  defmodule SavingConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:ok, %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}}}
    @impl Athanor.Editor
    def save(_socket, payload), do: send(self(), {:saved, payload}) && {:ok, :persisted}
  end

  defmodule FailingConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:ok, %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}}}
    @impl Athanor.Editor
    def save(_socket, _payload), do: {:error, :db_failed}
  end

  defmodule SeedingConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:ok, %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}}}
    @impl Athanor.Editor
    def save(_, _), do: {:ok, :saved}

    @impl Athanor.Editor
    def seed_default_props(component, "with_seed", _socket) do
      put_in(component, ["props", "seeded"], "yes")
    end

    @impl Athanor.Editor
    def seed_default_props(component, _type, _socket), do: component
  end

  defmodule FakeComponent do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "fake", label: "Fake"}
    def default_props, do: %{"x" => 1}
  end

  defmodule WithSeedComponent do
    use Athanor.Component
    @impl Athanor.Component
    def metadata, do: %{type: "with_seed", label: "WS"}
    def default_props, do: %{}
  end

  setup do
    Application.put_env(:athanor, :components, [FakeComponent, WithSeedComponent])
    on_exit(fn -> Application.put_env(:athanor, :components, []) end)
    :ok
  end

  # ─── add_component ─────────────────────────────────────────────────────

  describe "do_add_component" do
    test "appends a new node with merged default_props at the root" do
      state = State.new()

      new_state =
        EditorLive.do_add_component(state, SavingConsumer, "fake", %{}, mock_socket())

      assert [node] = new_state.content["content"]
      assert node["type"] == "fake"
      assert node["props"]["x"] == 1
      assert is_binary(node["id"])
      assert state.selected_component_id == nil
      assert new_state.selected_component_id == node["id"]
    end

    test "consumer's seed_default_props/3 is invoked" do
      state = State.new()

      new_state =
        EditorLive.do_add_component(state, SeedingConsumer, "with_seed", %{}, mock_socket())

      [node] = new_state.content["content"]
      assert node["props"]["seeded"] == "yes"
    end

    test "unknown type still adds a node with empty props (no crash)" do
      state = State.new()

      new_state =
        EditorLive.do_add_component(state, SavingConsumer, "ghost", %{}, mock_socket())

      assert [node] = new_state.content["content"]
      assert node["type"] == "ghost"
      assert node["props"] == %{}
    end
  end

  # ─── add_component_to_zone ─────────────────────────────────────────────

  describe "do_add_component_to_zone" do
    test "inserts new node into the named zone of the parent columns node" do
      state = %State{
        State.new()
        | content: %{
            "content" => [
              %{
                "id" => "col1",
                "type" => "columns",
                "props" => %{
                  "zone_names" => ["one", "two"],
                  "zones" => %{"one" => [], "two" => []}
                }
              }
            ]
          }
      }

      new_state =
        EditorLive.do_add_component_to_zone(
          state,
          SavingConsumer,
          "col1",
          "one",
          "fake",
          mock_socket()
        )

      [columns] = new_state.content["content"]
      [child] = columns["props"]["zones"]["one"]
      assert child["type"] == "fake"
      assert columns["props"]["zones"]["two"] == []
      assert new_state.column_picker == nil
      assert new_state.selected_component_id == child["id"]
    end

    test "clears column_picker even when insertion fails" do
      state = %State{State.new() | column_picker: {"missing", "zone"}}

      new_state =
        EditorLive.do_add_component_to_zone(
          state,
          SavingConsumer,
          "missing",
          "zone",
          "fake",
          mock_socket()
        )

      assert new_state.column_picker == nil
    end
  end

  # ─── remove_component ──────────────────────────────────────────────────

  describe "do_remove_component" do
    test "removes the node from the tree" do
      state = %State{
        State.new()
        | content: %{
            "content" => [
              %{"id" => "a", "type" => "fake", "props" => %{}},
              %{"id" => "b", "type" => "fake", "props" => %{}}
            ]
          },
          selected_component_id: "a"
      }

      new_state = EditorLive.do_remove_component(state, "a")

      assert [%{"id" => "b"}] = new_state.content["content"]
      assert new_state.selected_component_id == nil
    end

    test "unknown id is a no-op" do
      state = %State{State.new() | content: %{"content" => [%{"id" => "x"}]}}
      new_state = EditorLive.do_remove_component(state, "ghost")
      assert new_state.content == state.content
    end
  end

  # ─── move_component ────────────────────────────────────────────────────

  describe "do_move_component" do
    test "moves up" do
      state = %State{
        State.new()
        | content: %{
            "content" => [
              %{"id" => "a", "type" => "fake", "props" => %{}},
              %{"id" => "b", "type" => "fake", "props" => %{}}
            ]
          }
      }

      new_state = EditorLive.do_move_component(state, "b", "up")
      assert [%{"id" => "b"}, %{"id" => "a"}] = new_state.content["content"]
    end

    test "moves down" do
      state = %State{
        State.new()
        | content: %{
            "content" => [
              %{"id" => "a", "type" => "fake", "props" => %{}},
              %{"id" => "b", "type" => "fake", "props" => %{}}
            ]
          }
      }

      new_state = EditorLive.do_move_component(state, "a", "down")
      assert [%{"id" => "b"}, %{"id" => "a"}] = new_state.content["content"]
    end
  end

  # ─── save ──────────────────────────────────────────────────────────────

  describe "save handler" do
    test "success → put_flash :info" do
      socket = mock_socket(content: %{"content" => []}, metadata: %{"title" => "X"})

      {:noreply, new_socket} = EditorLive.handle_event(SavingConsumer, "save", %{}, socket)

      assert new_socket.assigns.flash["info"] =~ "Saved"
      assert_received {:saved, %{content: %{"content" => []}, metadata: %{"title" => "X"}}}
    end

    test "error → put_flash :error" do
      socket = mock_socket()

      {:noreply, new_socket} = EditorLive.handle_event(FailingConsumer, "save", %{}, socket)

      assert new_socket.assigns.flash["error"] =~ "Save failed"
      assert new_socket.assigns.flash["error"] =~ "db_failed"
    end
  end

  # ─── helpers ───────────────────────────────────────────────────────────

  defp mock_socket(opts \\ []) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        flash: %{},
        content: opts[:content] || %{"content" => []},
        metadata: opts[:metadata] || %{},
        selected_component_id: opts[:selected_component_id],
        column_picker: opts[:column_picker],
        preview_viewport: :desktop,
        show_components_panel: true,
        ctx: nil
      }
    }
  end
end
