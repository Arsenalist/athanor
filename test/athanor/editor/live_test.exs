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

  alias Athanor.Editor.Live, as: EditorLive
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

  defmodule OutletOverrideConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:ok, %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}}}
    @impl Athanor.Editor
    def save(_, _), do: {:ok, :saved}

    @impl Athanor.Editor
    def render_outlet(assigns), do: ~H"<div data-testid='custom-outlet'>PICKER</div>"
  end

  defmodule AssetConsumer do
    use Athanor.Editor.Live
    @impl Athanor.Editor
    def load(_, _, _), do: {:ok, %{content: %{"content" => []}, metadata: %{}, ctx_assigns: %{}}}
    @impl Athanor.Editor
    def save(_, _), do: {:ok, :saved}

    @impl Athanor.Editor
    def handle_asset_request(socket, req) do
      send(self(), {:asset_request, req})
      {:noreply, socket}
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

    test "default render_outlet renders nothing and is overridable" do
      assigns = %{}
      refute rendered_iodata_to_string(MinimalConsumer.render_outlet(assigns)) =~ "custom-outlet"

      assert rendered_iodata_to_string(OutletOverrideConsumer.render_outlet(assigns)) =~
               "custom-outlet"
    end

    test "injects render_outlet/1" do
      assert function_exported?(MinimalConsumer, :render_outlet, 1)
    end
  end

  describe "render_outlet in the shell" do
    test "override markup appears in the editor modals layer" do
      html = rendered_iodata_to_string(render_shell(OutletOverrideConsumer))
      assert html =~ "athanor-editor-modals"
      assert html =~ "custom-outlet"
    end

    test "default outlet adds no extra markup" do
      html = rendered_iodata_to_string(render_shell(MinimalConsumer))
      refute html =~ "custom-outlet"
    end
  end

  describe "handle_event athanor_asset_request" do
    test "routes to the consumer's handle_asset_request with a built AssetRequest" do
      socket =
        mock_socket(
          content: %{
            "content" => [
              %{"id" => "n1", "type" => "x", "props" => %{"hero" => %{"url" => "u0"}}}
            ]
          }
        )

      params = %{"node" => "n1", "key" => "hero", "accept" => "image/*", "max" => "5"}

      {:noreply, _} =
        EditorLive.handle_event(AssetConsumer, "athanor_asset_request", params, socket)

      assert_receive {:asset_request, req}
      assert req.node_id == "n1"
      assert req.key == "hero"
      assert req.accept == "image/*"
      assert req.max == 5
      assert req.current == %{"url" => "u0"}
    end

    test "multiple flag and page-settings current lookup" do
      socket = mock_socket(metadata: %{"gallery" => [%{"url" => "a"}]})
      params = %{"node" => "page-settings", "key" => "gallery", "multiple" => "true"}

      {:noreply, _} =
        EditorLive.handle_event(AssetConsumer, "athanor_asset_request", params, socket)

      assert_receive {:asset_request, req}
      assert req.multiple == true
      assert req.current == [%{"url" => "a"}]
    end

    test "does not crash when the consumer does not implement handle_asset_request/2" do
      socket = mock_socket()
      params = %{"node" => "n1", "key" => "hero"}

      # pending is still set (so render_outlet can show a picker); the optional
      # consumer callback is simply not invoked.
      {:noreply, s} =
        EditorLive.handle_event(MinimalConsumer, "athanor_asset_request", params, socket)

      assert %Athanor.Editor.AssetRequest{node_id: "n1", key: "hero"} = s.assigns.asset_request
    end
  end

  describe "asset_request pending lifecycle" do
    test "request sets pending state (even without a consumer callback)" do
      socket = mock_socket()
      params = %{"node" => "n1", "key" => "hero"}

      {:noreply, s} =
        EditorLive.handle_event(MinimalConsumer, "athanor_asset_request", params, socket)

      assert %Athanor.Editor.AssetRequest{node_id: "n1", key: "hero"} = s.assigns.asset_request
    end

    test "athanor_asset_cancel event clears pending" do
      socket =
        mock_socket() |> Phoenix.Component.assign(:asset_request, pending("n1", "hero", nil))

      {:noreply, s} =
        EditorLive.handle_event(MinimalConsumer, "athanor_asset_cancel", %{}, socket)

      assert s.assigns.asset_request == nil
    end

    test ":athanor_asset_cancel message clears pending (closure-based close)" do
      socket =
        mock_socket() |> Phoenix.Component.assign(:asset_request, pending("n1", "hero", nil))

      {:noreply, s} = EditorLive.handle_info(MinimalConsumer, :athanor_asset_cancel, socket)
      assert s.assigns.asset_request == nil
    end

    test "write-back to the pending key clears pending" do
      socket =
        mock_socket(content: %{"content" => [%{"id" => "n1", "type" => "x", "props" => %{}}]})
        |> Phoenix.Component.assign(:asset_request, pending("n1", "hero", nil))

      {:noreply, s} =
        EditorLive.handle_info(
          MinimalConsumer,
          {:update_component_props, "n1", %{"hero" => %{"url" => "u"}}},
          socket
        )

      assert s.assigns.asset_request == nil
    end

    test "unrelated-key write on the same node does NOT clear pending" do
      socket =
        mock_socket(content: %{"content" => [%{"id" => "n1", "type" => "x", "props" => %{}}]})
        |> Phoenix.Component.assign(:asset_request, pending("n1", "hero", nil))

      {:noreply, s} =
        EditorLive.handle_info(
          MinimalConsumer,
          {:update_component_props, "n1", %{"hero" => nil, "title" => "new"}},
          socket
        )

      assert s.assigns.asset_request != nil
    end

    test "page-settings write-back to the pending key clears pending" do
      socket =
        mock_socket(metadata: %{})
        |> Phoenix.Component.assign(:asset_request, pending("page-settings", "image", nil))

      {:noreply, s} =
        EditorLive.handle_info(
          MinimalConsumer,
          {:update_component_props, "page-settings", %{"image" => %{"url" => "u"}}},
          socket
        )

      assert s.assigns.asset_request == nil
    end

    test "select_component / close_config / remove_component clear pending" do
      base =
        mock_socket(content: %{"content" => [%{"id" => "n1", "type" => "x", "props" => %{}}]})
        |> Phoenix.Component.assign(:asset_request, pending("n1", "hero", nil))

      {:noreply, s1} =
        EditorLive.handle_event(MinimalConsumer, "select_component", %{"id" => "n1"}, base)

      assert s1.assigns.asset_request == nil

      {:noreply, s2} = EditorLive.handle_event(MinimalConsumer, "close_config", %{}, base)
      assert s2.assigns.asset_request == nil

      {:noreply, s3} =
        EditorLive.handle_event(MinimalConsumer, "remove_component", %{"id" => "n1"}, base)

      assert s3.assigns.asset_request == nil
    end
  end

  describe "handle_event athanor_asset_remove" do
    test "removes the descriptor with the matching url from a gallery list" do
      socket =
        mock_socket(
          content: %{
            "content" => [
              %{
                "id" => "n1",
                "type" => "x",
                "props" => %{"gallery" => [%{"url" => "a"}, %{"url" => "b"}]}
              }
            ]
          }
        )

      params = %{"node" => "n1", "key" => "gallery", "url" => "a"}

      {:noreply, new_socket} =
        EditorLive.handle_event(AssetConsumer, "athanor_asset_remove", params, socket)

      {:ok, node} = Athanor.Tree.find(new_socket.assigns.content, "n1")
      assert node["props"]["gallery"] == [%{"url" => "b"}]
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

  defp render_shell(consumer) do
    assigns = %{
      __changed__: %{},
      __consumer__: consumer,
      __page_settings__: nil,
      content: %{"content" => []},
      metadata: %{},
      ctx: Athanor.Ctx.new(edit_mode?: true),
      selected_component_id: nil,
      column_picker: nil,
      preview_viewport: :desktop,
      show_components_panel: true
    }

    Athanor.Editor.Live.shell_render(assigns)
  end

  defp pending(node_id, key, current) do
    %Athanor.Editor.AssetRequest{node_id: node_id, key: key, current: current}
  end

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
        ctx: Athanor.Ctx.new()
      }
    }
  end
end
