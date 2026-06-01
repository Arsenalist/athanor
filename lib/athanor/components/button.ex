defmodule Athanor.Components.Button do
  @moduledoc """
  Button primitive. Renders an HTML anchor styled as a DaisyUI button,
  wrapped in the shared formatting div.

  ## Props

  - `label` (string, required)
  - `href` (string, required)
  - `variant` (`"primary" | "secondary" | "ghost"`, default `"primary"`)
  - `size` (`"sm" | "md" | "lg"`, default `"md"`)
  - `target` (`"_self" | "_blank" | "_parent" | "_top"`, default `"_self"`)
  - `rel` (string, default `"noopener"`)
  - `formatting` (map, optional)
  """

  use Athanor.Component
  use Phoenix.Component

  alias Athanor.Components.Formatting

  @valid_variants ~w(primary secondary ghost)
  @valid_sizes ~w(sm md lg)
  @valid_targets ~w(_self _blank _parent _top)

  @impl Athanor.Component
  def metadata do
    %{
      type: "button",
      label: "Button",
      icon: "fa-square",
      category: :content,
      description: "DaisyUI-styled link button"
    }
  end

  @impl Athanor.Component
  def default_props do
    %{
      "label" => "Click",
      "href" => "#",
      "variant" => "primary",
      "size" => "md",
      "target" => "_self",
      "rel" => "noopener"
    }
  end

  @impl Athanor.Component
  def required_props, do: ["label", "href"]

  @impl Athanor.Component
  def editor_form, do: Athanor.Components.Button.EditorForm

  @impl Athanor.Component
  def render(:live, node, _ctx) do
    props = node["props"] || %{}
    formatting = props["formatting"] || %{}

    assigns = %{
      label: props["label"] || "",
      href: props["href"] || "#",
      classes: "btn btn-#{variant(props)} btn-#{size(props)}",
      target: target(props),
      rel: props["rel"] || "noopener",
      formatting: formatting
    }

    ~H"""
    <Formatting.apply formatting={@formatting}>
      <a class={@classes} href={@href} target={@target} rel={@rel}>{@label}</a>
    </Formatting.apply>
    """
  end

  defp variant(%{"variant" => v}) when v in @valid_variants, do: v
  defp variant(_), do: "primary"

  defp size(%{"size" => s}) when s in @valid_sizes, do: s
  defp size(_), do: "md"

  defp target(%{"target" => t}) when t in @valid_targets, do: t
  defp target(_), do: "_self"
end
