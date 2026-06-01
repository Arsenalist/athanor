defmodule Athanor.Ctx do
  @moduledoc """
  Context struct carried through every `Athanor.Renderer` dispatch.

  Holds two kinds of data:

  - **Passthrough**: `user_id`, `account_id`, `api_token`, `brand_id`,
    `cart_id`. Athanor does not interpret these — they exist so consumer
    apps can give their components the bits of session context they need
    (auth, scoping, current cart).

  - **Adapters**: `asset_picker`, `rich_text`, `data_sources`, `i18n`.
    These are pluggable behaviours that components consume instead of
    importing app-specific modules. v1 keeps the fields with `nil`
    defaults; adapter behaviours land in a later step.

  `extra` is a free-form map for consumer-side passthrough that doesn't fit
  the named fields (feature flags, request id, A/B test bucket, etc.).
  Athanor never inspects `extra`.

  ## Examples

      iex> ctx = Athanor.Ctx.new(account_id: "a1", cart_id: "c1")
      iex> ctx.account_id
      "a1"

      iex> Athanor.Ctx.new().data_sources
      %{}
  """

  defstruct user_id: nil,
            account_id: nil,
            api_token: nil,
            brand_id: nil,
            cart_id: nil,
            asset_picker: nil,
            rich_text: nil,
            data_sources: %{},
            i18n: nil,
            extra: %{}

  @type t :: %__MODULE__{
          user_id: String.t() | nil,
          account_id: String.t() | nil,
          api_token: String.t() | nil,
          brand_id: String.t() | nil,
          cart_id: String.t() | nil,
          asset_picker: module() | nil,
          rich_text: module() | nil,
          data_sources: %{String.t() => module()},
          i18n: module() | nil,
          extra: map()
        }

  @doc """
  Build an empty Ctx with all default values.
  """
  def new, do: %__MODULE__{}

  @doc """
  Build a Ctx with overrides supplied as a keyword list or map.

  Unknown keys raise `KeyError` to catch typos early.
  """
  def new(overrides) when is_list(overrides) do
    struct!(__MODULE__, overrides)
  end

  def new(overrides) when is_map(overrides) do
    struct!(__MODULE__, Map.to_list(overrides))
  end
end
