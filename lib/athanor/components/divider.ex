defmodule Athanor.Components.Divider do
  @moduledoc """
  Divider primitive. Renders an `<hr>` wrapped in the shared formatting
  div. Divider's own `thickness`/`color`/`margin_y` props control the
  rule itself; `formatting` controls the wrapping container.

  ## Props

  - `thickness` (integer 0..16, default `1`)
  - `color` (string hex `#RRGGBB`, default `"#e5e7eb"`)
  - `margin_y` (`"sm" | "md" | "lg"`, default `"md"`)
  - `formatting` (map, optional)
  """

  use Athanor.Component
  use Phoenix.Component

  alias Athanor.Components.Formatting

  @valid_margins ~w(sm md lg)
  @hex_regex ~r/^#[0-9a-fA-F]{6}$/

  @impl Athanor.Component
  def metadata do
    %{
      type: "divider",
      label: "Divider",
      icon: "fa-minus",
      category: :layout,
      description: "Horizontal rule"
    }
  end

  @impl Athanor.Component
  def default_props, do: %{"thickness" => 1, "color" => "#e5e7eb", "margin_y" => "md"}

  @impl Athanor.Component
  def required_props, do: []

  @impl Athanor.Component
  def editor_form, do: Athanor.Components.Divider.EditorForm

  @impl Athanor.Component
  def render(:live, node, _ctx) do
    props = node["props"] || %{}
    formatting = props["formatting"] || %{}

    thickness = clamp_thickness(props["thickness"])
    color = valid_color(props["color"])
    margin = valid_margin(props["margin_y"])

    assigns = %{
      classes: "my-#{margin}",
      style: "border-top-width:#{thickness}px;border-color:#{color};",
      formatting: formatting
    }

    ~H"""
    <Formatting.apply formatting={@formatting}>
      <hr class={@classes} style={@style} />
    </Formatting.apply>
    """
  end

  defp clamp_thickness(n) when is_integer(n) and n in 0..16, do: n
  defp clamp_thickness(n) when is_integer(n) and n < 0, do: 0
  defp clamp_thickness(n) when is_integer(n) and n > 16, do: 16

  defp clamp_thickness(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> clamp_thickness(n)
      _ -> 1
    end
  end

  defp clamp_thickness(_), do: 1

  defp valid_color(c) when is_binary(c) do
    if Regex.match?(@hex_regex, c), do: c, else: "#e5e7eb"
  end

  defp valid_color(_), do: "#e5e7eb"

  defp valid_margin(m) when m in @valid_margins, do: m
  defp valid_margin(_), do: "md"
end
