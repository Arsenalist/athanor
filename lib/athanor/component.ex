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

  ## Editor form

  Components that need a configuration UI return a `Phoenix.LiveComponent`
  module from `editor_form/0`. The editor LiveView mounts that LC in the
  config panel. Components without an editor form return `nil`.

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

  @callback default_props() :: props()
  @callback required_props() :: [String.t()]
  @callback validate(props()) :: :ok | {:error, term()}
  @callback render(target(), tree_node(), Athanor.Ctx.t()) :: any()
  @callback editor_form() :: module() | nil
  @callback child_zones(tree_node()) :: %{String.t() => [tree_node()]}

  @optional_callbacks [
    default_props: 0,
    required_props: 0,
    validate: 1,
    render: 3,
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
      def editor_form, do: nil

      @impl Athanor.Component
      def child_zones(_node), do: %{}

      defoverridable default_props: 0,
                     required_props: 0,
                     validate: 1,
                     editor_form: 0,
                     child_zones: 1
    end
  end
end
