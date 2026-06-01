defmodule Athanor.Components.Text do
  @moduledoc """
  Text primitive. Renders raw HTML stored in `node["props"]["text"]`
  wrapped by `Athanor.Components.Formatting.apply/1` so the legacy
  formatting props (padding, margin, colors, alignment, border) continue
  to work — round-trips byte-equal with prod data shape.

  ## Documented exception

  `editor_form/0` returns `AmplifyWeb.PageBuilder.Components.Text` — the
  legacy LiveComponent in Amplify. This is the ONE place an Athanor module
  references an `AmplifyWeb.*` atom. Justified because we're explicitly
  bridging Text editing to the existing rich-text editor + media manager
  flow. The reference is to the atom only; the module is never aliased
  or imported. The athanor architecture test allows this single exception.
  """

  use Athanor.Component
  use Phoenix.Component

  alias Athanor.Components.Formatting

  @impl Athanor.Component
  def metadata do
    %{
      type: "text",
      label: "Text",
      icon: "fa-align-left",
      category: :content,
      description: "Formatted text content"
    }
  end

  @impl Athanor.Component
  def default_props, do: %{"text" => ""}

  @impl Athanor.Component
  def required_props, do: ["text"]

  @impl Athanor.Component
  def validate(props) do
    text = (props || %{})["text"]

    if is_binary(text) and text != "",
      do: :ok,
      else: {:error, {:missing, ["text"]}}
  end

  @impl Athanor.Component
  def editor_form, do: AmplifyWeb.PageBuilder.Components.Text

  @impl Athanor.Component
  def render(:live, node, _ctx) do
    props = node["props"] || %{}
    formatting = props["formatting"] || %{}

    assigns = %{
      html: props["text"] || "",
      formatting: formatting
    }

    ~H"""
    <Formatting.apply formatting={@formatting}>
      {Phoenix.HTML.raw(@html)}
    </Formatting.apply>
    """
  end
end
