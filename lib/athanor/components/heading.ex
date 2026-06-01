defmodule Athanor.Components.Heading do
  @moduledoc """
  Heading primitive. Renders a semantic `<h1>`–`<h6>` wrapped in the
  shared formatting div so the host's Tailwind config doesn't override
  spacing/colors.

  ## Props

  - `text` (string, required) — heading text
  - `level` (1..6, default 2) — heading level
  - `formatting` (map, optional) — see `Athanor.Components.Formatting`
  """

  use Athanor.Component
  use Phoenix.Component

  alias Athanor.Components.Formatting

  @impl Athanor.Component
  def metadata do
    %{
      type: "heading",
      label: "Heading",
      icon: "fa-heading",
      category: :content,
      description: "Semantic heading (h1–h6)"
    }
  end

  @impl Athanor.Component
  def default_props, do: %{"text" => "Heading text", "level" => 2}

  @impl Athanor.Component
  def required_props, do: ["text"]

  @impl Athanor.Component
  def editor_form, do: Athanor.Components.Heading.EditorForm

  @impl Athanor.Component
  def render(:live, node, _ctx) do
    props = node["props"] || %{}
    formatting = props["formatting"] || %{}

    assigns = %{
      text: props["text"] || "",
      level: clamp_level(props["level"]),
      formatting: formatting
    }

    ~H"""
    <Formatting.apply formatting={@formatting}>
      <.heading_tag level={@level} text={@text} />
    </Formatting.apply>
    """
  end

  attr :level, :integer, required: true
  attr :text, :string, required: true

  defp heading_tag(%{level: 1} = assigns), do: ~H|<h1>{@text}</h1>|
  defp heading_tag(%{level: 2} = assigns), do: ~H|<h2>{@text}</h2>|
  defp heading_tag(%{level: 3} = assigns), do: ~H|<h3>{@text}</h3>|
  defp heading_tag(%{level: 4} = assigns), do: ~H|<h4>{@text}</h4>|
  defp heading_tag(%{level: 5} = assigns), do: ~H|<h5>{@text}</h5>|
  defp heading_tag(%{level: 6} = assigns), do: ~H|<h6>{@text}</h6>|

  defp clamp_level(n) when is_integer(n) and n in 1..6, do: n
  defp clamp_level(n) when is_integer(n) and n < 1, do: 1
  defp clamp_level(n) when is_integer(n) and n > 6, do: 6

  defp clamp_level(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> clamp_level(n)
      _ -> 2
    end
  end

  defp clamp_level(_), do: 2
end
