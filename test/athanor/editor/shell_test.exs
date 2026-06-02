defmodule Athanor.Editor.ShellTest do
  @moduledoc """
  Tests for the `Athanor.Editor.shell/1` function component — the layout
  primitive used by both the turn-key `use Athanor.Editor.Live` path and
  consumer-assembled LiveViews.

  Shell renders structure (top bar + 3 columns + modal layer) with named
  slots for content; slots default to empty when not provided. Consumer
  fills slots with library LiveComponents (Canvas, ComponentsPanel,
  ConfigPanel, ZonePickerModal) — or their own widgets.
  """

  use ExUnit.Case, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Editor

  # ─── default rendering (no slots) ──────────────────────────────────────

  describe "default rendering (no slots)" do
    test "renders the structural shell with testids for each region" do
      html = render_shell(%{})

      assert html =~ ~s(data-testid="athanor-editor-shell")
      assert html =~ ~s(data-testid="athanor-editor-header")
      assert html =~ ~s(data-testid="athanor-editor-sidebar-left")
      assert html =~ ~s(data-testid="athanor-editor-canvas")
      assert html =~ ~s(data-testid="athanor-editor-sidebar-right")
      assert html =~ ~s(data-testid="athanor-editor-modals")
    end

    test "regions are empty when no slot content provided" do
      html = render_shell(%{})

      # All regions are present (structural) but contain no consumer markup.
      refute html =~ "CONSUMER_HEADER"
      refute html =~ "CONSUMER_LEFT"
      refute html =~ "CONSUMER_RIGHT"
      refute html =~ "CONSUMER_MODAL"
    end
  end

  # ─── slot rendering ────────────────────────────────────────────────────

  describe ":header slot" do
    test "content placed in :header slot renders inside the header region" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell>
              <:header>CONSUMER_HEADER</:header>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "CONSUMER_HEADER"
      # And it lives inside the header region, not somewhere else.
      [_, after_header] = String.split(html, ~s(data-testid="athanor-editor-header"), parts: 2)
      assert String.contains?(after_header, "CONSUMER_HEADER")
    end
  end

  describe ":sidebar_left slot" do
    test "content renders inside the left sidebar region" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell>
              <:sidebar_left>CONSUMER_LEFT</:sidebar_left>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "CONSUMER_LEFT"

      [_, after_left] =
        String.split(html, ~s(data-testid="athanor-editor-sidebar-left"), parts: 2)

      assert String.contains?(after_left, "CONSUMER_LEFT")
    end
  end

  describe ":sidebar_right slot" do
    test "content renders inside the right sidebar region" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell>
              <:sidebar_right>CONSUMER_RIGHT</:sidebar_right>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "CONSUMER_RIGHT"

      [_, after_right] =
        String.split(html, ~s(data-testid="athanor-editor-sidebar-right"), parts: 2)

      assert String.contains?(after_right, "CONSUMER_RIGHT")
    end
  end

  describe ":modals slot" do
    test "content renders inside the modal layer region" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell>
              <:modals>CONSUMER_MODAL</:modals>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "CONSUMER_MODAL"

      [_, after_modals] =
        String.split(html, ~s(data-testid="athanor-editor-modals"), parts: 2)

      assert String.contains?(after_modals, "CONSUMER_MODAL")
    end
  end

  # ─── shell attrs propagating into slot context ─────────────────────────

  describe "shell attrs propagate to slots" do
    test "page_title attr is accessible inside :header slot" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell page_title="PAGE_X">
              <:header :let={ctx}>title={ctx.page_title}</:header>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "title=PAGE_X"
    end

    test "selected_component_id attr is accessible inside :sidebar_right slot" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell selected_component_id="c-42">
              <:sidebar_right :let={ctx}>selected={ctx.selected_component_id}</:sidebar_right>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "selected=c-42"
    end

    test "viewport attr is accessible inside :header slot" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell viewport={:tablet}>
              <:header :let={ctx}>viewport={ctx.viewport}</:header>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "viewport=tablet"
    end
  end

  # ─── all slots together ────────────────────────────────────────────────

  describe "all slots together" do
    test "every slot region's content shows up at once" do
      html =
        render_component(
          fn assigns ->
            ~H"""
            <Editor.shell>
              <:header>HDR_X</:header>
              <:sidebar_left>LFT_X</:sidebar_left>
              <:sidebar_right>RGT_X</:sidebar_right>
              <:modals>MOD_X</:modals>
            </Editor.shell>
            """
          end,
          %{}
        )

      assert html =~ "HDR_X"
      assert html =~ "LFT_X"
      assert html =~ "RGT_X"
      assert html =~ "MOD_X"
    end
  end

  # ─── helper ────────────────────────────────────────────────────────────

  defp render_shell(_opts) do
    render_component(
      fn assigns ->
        ~H"""
        <Editor.shell />
        """
      end,
      %{}
    )
  end
end
