defmodule Athanor.Editor.CanvasTest do
  @moduledoc """
  Tests for `Athanor.Editor.canvas/1` — function component that renders
  the editor canvas (the middle column). Iterates top-level nodes in
  the content tree, wraps each with edit chrome (Configure button +
  selection border), and dispatches per-node rendering via
  `Athanor.Renderer.node_component/1`.
  """

  use ExUnit.Case, async: false
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Ctx
  alias Athanor.Editor

  defmodule FakeComponent do
    use Athanor.Component
    def metadata, do: %{type: "fake", label: "Fake"}
    def required_props, do: ["title"]

    def render(:live, node, _ctx) do
      assigns = %{title: node["props"]["title"]}
      ~H"""
      <div data-testid="fake-render">FAKE:{@title}</div>
      """
    end
  end

  setup do
    Application.put_env(:athanor, :components, [FakeComponent])
    on_exit(fn -> Application.put_env(:athanor, :components, []) end)
    :ok
  end

  defp render_canvas(content, opts \\ []) do
    assigns = %{
      content: content,
      ctx: opts[:ctx] || Ctx.new(edit_mode?: true),
      selected_component_id: opts[:selected_component_id]
    }

    render_component(
      fn assigns ->
        ~H"""
        <Editor.canvas
          content={@content}
          ctx={@ctx}
          selected_component_id={@selected_component_id}
        />
        """
      end,
      assigns
    )
  end

  describe "empty content" do
    test "renders the canvas container with an empty-state message" do
      html = render_canvas(%{"content" => []})
      assert html =~ ~s(data-testid="athanor-canvas")
      assert html =~ "No components"
    end
  end

  describe "single valid node" do
    test "renders the node via Athanor.Renderer with edit chrome" do
      content = %{"content" => [%{"id" => "n1", "type" => "fake", "props" => %{"title" => "T"}}]}

      html = render_canvas(content)

      assert html =~ "FAKE:T"
      # Edit chrome present in edit_mode.
      assert html =~ ~s(data-testid="athanor-canvas-item")
    end

    test "renders a Configure button per top-level node when select_component_callback is set" do
      content = %{"content" => [%{"id" => "n1", "type" => "fake", "props" => %{"title" => "T"}}]}
      cb = fn _id -> Phoenix.LiveView.JS.push("select_component") end
      ctx = Ctx.new(edit_mode?: true, select_component_callback: cb)

      html = render_canvas(content, ctx: ctx)
      assert html =~ ~s(data-testid="athanor-canvas-configure-n1")
    end

    test "selected node gets a distinct border class" do
      content = %{"content" => [%{"id" => "n1", "type" => "fake", "props" => %{"title" => "T"}}]}

      html_selected = render_canvas(content, selected_component_id: "n1")
      html_unselected = render_canvas(content, selected_component_id: nil)

      assert html_selected =~ "border-primary"
      refute html_unselected =~ "border-primary"
    end
  end

  describe "multiple nodes" do
    test "renders each node in order" do
      content = %{
        "content" => [
          %{"id" => "a", "type" => "fake", "props" => %{"title" => "ONE"}},
          %{"id" => "b", "type" => "fake", "props" => %{"title" => "TWO"}}
        ]
      }

      html = render_canvas(content)
      assert html =~ "FAKE:ONE"
      assert html =~ "FAKE:TWO"
      pos_one = :binary.match(html, "FAKE:ONE") |> elem(0)
      pos_two = :binary.match(html, "FAKE:TWO") |> elem(0)
      assert pos_one < pos_two
    end
  end

  describe "viewport class" do
    test "applies max-width class for tablet viewport" do
      ctx = Ctx.new(edit_mode?: true, extra: %{viewport: :tablet})
      content = %{"content" => []}

      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.canvas
              content={@content}
              ctx={@ctx}
              viewport={:tablet}
            />
            """
          end,
          %{content: content, ctx: ctx}
        )

      # tablet ≈ 768px container
      assert html =~ "max-w-[768px]" or html =~ "tablet"
    end
  end
end
