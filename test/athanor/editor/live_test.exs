defmodule Athanor.Editor.LiveTest do
  @moduledoc """
  Tests for `Athanor.Editor.Live` — the turn-key LiveView macro.

  Strategy: macro injects thin glue that delegates to public functions
  on `Athanor.Editor.Live`. We unit-test the underlying delegation
  functions with mock sockets + fake consumer modules; macro mechanics
  themselves get a thin smoke test (verify the right functions are
  exported on the consumer module).

  End-to-end LV mount tests live on the Amplify side once the consumer
  PageBuilderLive is migrated.
  """

  use ExUnit.Case, async: true
  use Phoenix.Component

  alias Athanor.Editor.State

  # ─── fake consumer modules ─────────────────────────────────────────────

  defmodule MinimalConsumer do
    use Athanor.Editor.Live

    @impl Athanor.Editor
    def load(_params, _session, _socket) do
      {:ok,
       %{
         content: %{"content" => []},
         metadata: %{},
         ctx_assigns: %{}
       }}
    end

    @impl Athanor.Editor
    def save(_socket, _state), do: {:ok, :saved}
  end

  defmodule LoadingConsumer do
    use Athanor.Editor.Live

    @impl Athanor.Editor
    def load(_params, _session, _socket) do
      {:ok,
       %{
         content: %{"content" => [%{"id" => "n1", "type" => "text", "props" => %{}}]},
         metadata: %{"title" => "Hello"},
         ctx_assigns: %{account_id: "acct_1", brand_id: "brand_1"}
       }}
    end

    @impl Athanor.Editor
    def save(_socket, _state), do: {:ok, :saved}
  end

  defmodule ErrorConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:error, :not_found}
    @impl Athanor.Editor
    def save(_, _), do: {:ok, :saved}
  end

  defmodule HeaderOverrideConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:ok, %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}}}
    @impl Athanor.Editor
    def save(_, _), do: {:ok, :saved}

    @impl Athanor.Editor
    def render_header(assigns), do: ~H"<div data-testid='custom-header'>CUSTOM</div>"
  end

  defmodule ActionsOverrideConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:ok, %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}}}
    @impl Athanor.Editor
    def save(_, _), do: {:ok, :saved}

    @impl Athanor.Editor
    def render_top_bar_actions(assigns) do
      ~H"<div data-testid='custom-actions'>BTNS</div>"
    end
  end

  # ─── macro mechanics ───────────────────────────────────────────────────

  describe "use Athanor.Editor.Live" do
    test "injects mount/3" do
      assert function_exported?(MinimalConsumer, :mount, 3)
    end

    test "injects render/1" do
      assert function_exported?(MinimalConsumer, :render, 1)
    end

    test "injects handle_event/3" do
      assert function_exported?(MinimalConsumer, :handle_event, 3)
    end

    test "injects handle_info/2" do
      assert function_exported?(MinimalConsumer, :handle_info, 2)
    end

    test "default render_header is overridable" do
      assigns = %{}
      default = MinimalConsumer.render_header(assigns)
      custom = HeaderOverrideConsumer.render_header(assigns)

      refute Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(rendered_to_iodata(default))) =~
               "custom-header"

      assert Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(rendered_to_iodata(custom))) =~
               "custom-header"
    end

    test "default render_top_bar_actions is overridable" do
      assigns = %{}
      default = MinimalConsumer.render_top_bar_actions(assigns)
      custom = ActionsOverrideConsumer.render_top_bar_actions(assigns)

      refute rendered_iodata_to_string(default) =~ "custom-actions"
      assert rendered_iodata_to_string(custom) =~ "custom-actions"
    end
  end

  # ─── delegation functions (unit-tested directly) ──────────────────────

  describe "build_initial_state/2" do
    test "constructs State from consumer load/3 result" do
      load_result = %{
        content: %{"content" => [%{"id" => "n1"}]},
        metadata: %{"title" => "Hi"},
        ctx_assigns: %{account_id: "a1", brand_id: "b1"}
      }

      state = Athanor.Editor.Live.build_initial_state(load_result, %{})

      assert %State{} = state
      assert state.content == %{"content" => [%{"id" => "n1"}]}
      assert state.metadata == %{"title" => "Hi"}
      assert state.ctx.account_id == "a1"
      assert state.ctx.brand_id == "b1"
      assert state.ctx.edit_mode? == true
    end

    test "ctx populated with select + add component callbacks" do
      state =
        Athanor.Editor.Live.build_initial_state(
          %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}},
          %{}
        )

      assert is_function(state.ctx.add_component_callback, 1)
      assert is_function(state.ctx.select_component_callback, 1)
    end

    test "options override default viewport / panel state" do
      state =
        Athanor.Editor.Live.build_initial_state(
          %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}},
          %{preview_viewport: :tablet, show_components_panel: false}
        )

      assert state.preview_viewport == :tablet
      assert state.show_components_panel == false
    end
  end

  describe "delegation handlers (unit tests)" do
    test "select_component sets selected_component_id" do
      state = State.new()
      new_state = Athanor.Editor.Live.do_select_component(state, "abc")
      assert new_state.selected_component_id == "abc"
    end

    test "close_config clears selected_component_id" do
      state = State.new(selected_component_id: "x")
      new_state = Athanor.Editor.Live.do_close_config(state)
      assert new_state.selected_component_id == nil
    end

    test "set_viewport updates preview_viewport" do
      state = State.new()
      new_state = Athanor.Editor.Live.do_set_viewport(state, "tablet")
      assert new_state.preview_viewport == :tablet
    end

    test "set_viewport rejects invalid values" do
      state = State.new()
      # Invalid input keeps current viewport
      new_state = Athanor.Editor.Live.do_set_viewport(state, "bogus")
      assert new_state.preview_viewport == :desktop
    end

    test "toggle_components_panel flips show_components_panel" do
      state = State.new(show_components_panel: true)
      flipped = Athanor.Editor.Live.do_toggle_components_panel(state)
      assert flipped.show_components_panel == false

      reflipped = Athanor.Editor.Live.do_toggle_components_panel(flipped)
      assert reflipped.show_components_panel == true
    end

    test "show_zone_picker sets column_picker" do
      state = State.new()
      new_state = Athanor.Editor.Live.do_show_zone_picker(state, "parent_x", "zone_one")
      assert new_state.column_picker == {"parent_x", "zone_one"}
    end

    test "cancel_zone_picker clears column_picker" do
      state = State.new(column_picker: {"p", "z"})
      new_state = Athanor.Editor.Live.do_cancel_zone_picker(state)
      assert new_state.column_picker == nil
    end
  end

  # ─── helpers ───────────────────────────────────────────────────────────

  defp rendered_iodata_to_string(rendered) do
    rendered
    |> rendered_to_iodata()
    |> IO.iodata_to_binary()
  end

  defp rendered_to_iodata(%Phoenix.LiveView.Rendered{} = rendered) do
    Phoenix.HTML.Safe.to_iodata(rendered)
  end
end
