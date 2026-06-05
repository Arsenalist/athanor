defmodule Athanor.Editor.AssetRequest do
  @moduledoc """
  Describes a request for an asset, emitted by an `:asset` field and routed
  to the host's `c:Athanor.Editor.handle_asset_request/2`.

  Athanor builds this struct and hands it to the host; it never performs the
  upload or browse itself. The host reads the declaration (`accept`,
  `multiple`, `min`, `max`) and `current` value to open whatever picker it
  wants, then writes the result back via the existing
  `{:update_component_props, node_id, props}` channel.

  Passing a struct (rather than positional args) lets the contract grow new
  fields without changing the callback arity.

  ## Fields

  - `:node_id` — id of the node whose prop is being set (required). The
    reserved id `"page-settings"` targets the page-settings form.
  - `:key` — the field key within that node's props (required).
  - `:accept` — opaque accept hint forwarded from the field declaration
    (e.g. `"image/*"` or `[".pdf"]`). Athanor does not enforce it.
  - `:multiple` — `true` when the field collects a list of assets.
  - `:min` / `:max` — cardinality bounds forwarded to the host (host-enforced).
  - `:current` — the current value of the prop, so the host can choose to add
    to a gallery vs replace. A descriptor map, a list of descriptors, or `nil`.
  """

  @enforce_keys [:node_id, :key]
  defstruct [:node_id, :key, :accept, :multiple, :max, :min, :current]

  @type descriptor :: %{required(String.t()) => any()}

  @type t :: %__MODULE__{
          node_id: String.t(),
          key: String.t(),
          accept: String.t() | [String.t()] | nil,
          multiple: boolean() | nil,
          max: non_neg_integer() | nil,
          min: non_neg_integer() | nil,
          current: descriptor() | [descriptor()] | nil
        }
end
