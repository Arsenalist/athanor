defmodule Athanor.Components.Text do
  @moduledoc """
  Text primitive. Renders raw HTML stored in `node["props"]["text"]`
  wrapped by `Athanor.Components.Formatting.apply/1` so the standard
  formatting props (padding, margin, colors, alignment, border) apply.

  ## Editor form (rich text)

  Athanor has no built-in rich-text editor — text editing UIs are heavy
  and opinionated (TipTap, Trix, Quill, custom). Consumers wire their
  own by registering a `Phoenix.LiveComponent` via application config:

      # config/config.exs (consumer app)
      config :athanor, text_editor_form: MyApp.PageBuilder.RichTextField

  `c:Athanor.Component.editor_form/0` reads that value at runtime. When
  unset (the default), it returns `nil` and Athanor falls back to the
  auto-generated `:textarea` field declared in `c:Athanor.Component.fields/0`.

  The registered LC receives the same assigns as any custom field LC
  documented in `Athanor.Field` — `:value`, `:on_change`, `:ctx`,
  `:label`, `:opts`.
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
  def editor_form, do: Application.get_env(:athanor, :text_editor_form)

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
