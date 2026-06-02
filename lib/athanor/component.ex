defmodule Athanor.Component do
  @moduledoc """
  Behaviour every Athanor-aware component implements.

  At v1 only `metadata/0` is required. Every other callback has a default
  injected by `use Athanor.Component` that components can override at will.

  ## Defining a component

      defmodule MyApp.Components.Promo do
        use Athanor.Component

        @impl Athanor.Component
        def metadata, do: %{type: "promo", label: "Promo", icon: "fa-bullhorn"}

        @impl Athanor.Component
        def required_props, do: ["headline"]

        @impl Athanor.Component
        def render(:live, node, _ctx) do
          assigns = %{headline: node["props"]["headline"]}
          ~H"<h2>{@headline}</h2>"
        end
      end

  ## Render targets

  Only `:live` is supported in v1. Future steps add `:static`, `:mjml`, `:text`
  without breaking the callback signature.

  ## Editor configuration: two ways

  Components describe how they are edited in one of two ways.

  ### Preferred: `fields/0` (declarative)

  Return a list of field tuples describing inputs. Athanor auto-generates
  the configure panel.

      def fields, do: [
        {"title", :text,     label: "Title"},
        {"level", :select,   label: "Level", options: [{"H1", "1"}, {"H2", "2"}]},
        {"image", :custom,   label: "Image", module: MyApp.MediaPicker}
      ]

  Built-in types: `:text`, `:textarea`, `:number`, `:select`, `:color`,
  `:checkbox`. The `:custom` type mounts a consumer-supplied module
  implementing `Athanor.Field`. See `Athanor.Field` and `Athanor.Fields`.

  ### Legacy: `editor_form/0` (LiveComponent)

  Return a `Phoenix.LiveComponent` module the editor mounts directly.
  Use this when you need state, multi-step flows, or behaviour the
  built-in field types don't cover. Return `nil` (default) for no
  configuration.

  ### Dispatch order

  When both are defined, `fields/0` (returning a non-empty list) wins.
  See `Athanor.Renderer` for the full dispatch rules.

  ## Child zones

  Container components (e.g., Columns) override `child_zones/1` to expose
  their children to `Athanor.Tree` walk/find/insert/remove/move. Default
  is no children.
  """

  @type target :: :live
  @type props :: map()
  @type tree_node :: %{required(String.t()) => any()}

  @callback metadata() :: %{
              required(:type) => String.t(),
              required(:label) => String.t(),
              optional(:icon) => String.t(),
              optional(:category) => atom(),
              optional(:description) => String.t(),
              optional(:placeholder) => String.t()
            }

  @type field_type :: :text | :textarea | :number | :select | :color | :checkbox | :custom
  @type field :: {String.t(), field_type(), keyword()}

  @callback default_props() :: props()
  @callback required_props() :: [String.t()]
  @callback validate(props()) :: :ok | {:error, term()}
  @callback render(target(), tree_node(), Athanor.Ctx.t()) :: any()
  @callback fields() :: [field()]
  @callback resolve_fields(props(), map()) :: [field()]
  @callback resolve_data(old_props :: props(), new_props :: props()) :: props()
  @callback editor_form() :: module() | nil
  @callback child_zones(tree_node()) :: %{String.t() => [tree_node()]}

  @optional_callbacks [
    default_props: 0,
    required_props: 0,
    validate: 1,
    render: 3,
    fields: 0,
    resolve_fields: 2,
    resolve_data: 2,
    editor_form: 0,
    child_zones: 1
  ]

  @doc """
  Default `validate/1` used when a component does not override.

  Returns `:ok` if every key listed in `required_props/0` is present and
  non-blank in `props`. Otherwise `{:error, {:missing, [missing_keys]}}`.
  """
  def default_validate(props, required) when is_map(props) and is_list(required) do
    missing = Enum.filter(required, &blank?(Map.get(props, &1)))

    if missing == [], do: :ok, else: {:error, {:missing, missing}}
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defmacro __using__(_opts) do
    quote do
      @behaviour Athanor.Component

      @impl Athanor.Component
      def default_props, do: %{}

      @impl Athanor.Component
      def required_props, do: []

      @impl Athanor.Component
      def validate(props),
        do: Athanor.Component.default_validate(props, required_props())

      @impl Athanor.Component
      def fields, do: []

      @impl Athanor.Component
      def resolve_fields(_props, _opts), do: fields()

      @impl Athanor.Component
      def resolve_data(_old, new), do: new

      @impl Athanor.Component
      def editor_form, do: nil

      @impl Athanor.Component
      def child_zones(_node), do: %{}

      defoverridable default_props: 0,
                     required_props: 0,
                     validate: 1,
                     fields: 0,
                     resolve_fields: 2,
                     resolve_data: 2,
                     editor_form: 0,
                     child_zones: 1
    end
  end
end
