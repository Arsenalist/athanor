defmodule Athanor.Components.Formatting do
  @moduledoc """
  Shared formatting surface for Athanor primitives.

  Every component that ships with Athanor wraps its render output in
  `apply/1`, which emits a div with the inline styles + alignment class
  derived from `node["props"]["formatting"]`. The field set matches the
  legacy host-app formatting config exactly, so existing prod data
  round-trips byte-equal.

  ## Field set (matches legacy `@style_options`)

  - `text_color`         hex like `"#000000"`
  - `background_color`   hex
  - `padding_top`        integer px
  - `padding_bottom`     integer px
  - `padding_left`       integer px
  - `padding_right`      integer px
  - `border_radius`      integer px
  - `border_width`       integer px
  - `border_color`       hex
  - `margin_top`         integer px
  - `margin_bottom`      integer px
  - `margin_left`        integer px
  - `margin_right`       integer px

  Plus `alignment` (`"left" | "center" | "right"`) which maps to a flex
  utility class.
  """

  use Phoenix.Component

  @style_options ~w(
    text_color background_color
    padding_top padding_bottom padding_left padding_right
    border_radius border_width border_color
    margin_top margin_bottom margin_left margin_right
  )

  @doc "Static list of supported style field keys."
  def style_options, do: @style_options

  @doc """
  Wrap rendered content with the formatting div.

  Usage from a component's `render(:live, ...)`:

      def render(:live, node, _ctx) do
        formatting = node["props"]["formatting"] || %{}
        assigns = %{
          formatting: formatting,
          inner: ~H"<h2>{node["props"]["text"]}</h2>"
        }

        Athanor.Components.Formatting.apply(assigns)
      end
  """
  attr :formatting, :map, default: %{}
  slot :inner_block, required: false
  attr :inner, :any, default: nil

  def apply(assigns) do
    ~H"""
    <div class={alignment_class(@formatting)} style={build_style(@formatting)}>
      <%= if @inner do %>
        {@inner}
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </div>
    """
  end

  @doc """
  Compute the inline `style="..."` value from a formatting map. Returns
  an empty string when no style fields are set.
  """
  def build_style(formatting) when is_map(formatting) do
    Enum.map_join(@style_options, ";", &style_fragment(formatting, &1))
  end

  def build_style(_), do: ""

  @doc """
  Map the `alignment` formatting key to a Tailwind flex class. Falls back
  to an empty string when unset or unknown.
  """
  def alignment_class(%{"alignment" => "center"}), do: "flex justify-center"
  def alignment_class(%{"alignment" => "right"}), do: "flex justify-end"
  def alignment_class(_), do: ""

  defp style_fragment(f, "text_color"), do: color_style("color", f["text_color"])

  defp style_fragment(f, "background_color"),
    do: color_style("background-color", f["background_color"])

  defp style_fragment(f, "border_color"), do: color_style("border-color", f["border_color"])
  defp style_fragment(f, "padding_top"), do: px_style("padding-top", f["padding_top"])
  defp style_fragment(f, "padding_bottom"), do: px_style("padding-bottom", f["padding_bottom"])
  defp style_fragment(f, "padding_left"), do: px_style("padding-left", f["padding_left"])
  defp style_fragment(f, "padding_right"), do: px_style("padding-right", f["padding_right"])
  defp style_fragment(f, "border_radius"), do: px_style("border-radius", f["border_radius"])
  defp style_fragment(f, "border_width"), do: px_style("border-width", f["border_width"])
  defp style_fragment(f, "margin_top"), do: px_style("margin-top", f["margin_top"])
  defp style_fragment(f, "margin_bottom"), do: px_style("margin-bottom", f["margin_bottom"])
  defp style_fragment(f, "margin_left"), do: px_style("margin-left", f["margin_left"])
  defp style_fragment(f, "margin_right"), do: px_style("margin-right", f["margin_right"])

  defp color_style(_attr, nil), do: ""
  defp color_style(_attr, ""), do: ""
  defp color_style(attr, value) when is_binary(value), do: "#{attr}: #{value};"
  defp color_style(_attr, _), do: ""

  defp px_style(_attr, nil), do: ""
  defp px_style(_attr, ""), do: ""
  defp px_style(attr, value) when is_integer(value), do: "#{attr}: #{value}px;"

  defp px_style(attr, value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> "#{attr}: #{n}px;"
      _ -> ""
    end
  end

  defp px_style(_attr, _), do: ""
end
