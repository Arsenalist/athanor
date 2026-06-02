defmodule Athanor.Field do
  @moduledoc """
  Behaviour for consumer-supplied `:custom` field modules.

  A `:custom` field declared in `c:Athanor.Component.fields/0` points at a
  module implementing this behaviour:

      def fields, do: [
        {"image", :custom, label: "Image", module: MyApp.PageBuilder.Fields.MediaPicker}
      ]

  The module IS a `Phoenix.LiveComponent`. Athanor mounts it inside the
  auto-generated configure panel with these assigns:

  - `:value` — current value of the prop (`props[key]`), or `nil` if unset
  - `:on_change` — 1-arity function. Call it with the new value and
                   Athanor plumbs `:update_component_props` back to the
                   host LiveView. Wholesale replace of `props[key]`.
  - `:ctx` — the full `Athanor.Ctx`. Use for passthrough context like
             `account_id`, `user_id`, `api_token`, etc.
  - `:label` — optional, declared via `label:` in the field opts.

  The custom LC owns its own UI completely. It can mount more LCs inside,
  hit the DB, render whatever HTML it wants. Athanor stays out of the way.

  ## Example

      defmodule MyApp.PageBuilder.Fields.MediaPicker do
        use Phoenix.LiveComponent

        @behaviour Athanor.Field

        @impl true
        def update(assigns, socket) do
          {:ok, assign(socket, assigns)}
        end

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <div>
            <img :if={@value} src={@value} class="..." />
            <button phx-click="pick" phx-target={@myself}>Pick image</button>
          </div>
          \"\"\"
        end

        @impl true
        def handle_event("pick", _params, socket) do
          # Open media picker, get url back, then:
          socket.assigns.on_change.(url)
          {:noreply, socket}
        end
      end

  ## Why a LiveComponent and not a function component

  Picker flows commonly need their own state (file uploads, async loads,
  multi-step modals). A `Phoenix.LiveComponent` lets the custom field
  own that state without leaking into the host LiveView.
  """

  # No callbacks declared here on purpose — `update/2` and `render/1`
  # already come from `Phoenix.LiveComponent`, which `:custom` field
  # modules use. Redeclaring them here just produced "conflicting
  # behaviours" warnings without adding any contract value.

  @doc """
  Returns `true` when `module` implements the `Athanor.Field` behaviour
  (or at minimum exports the required LiveComponent callbacks).
  """
  def implements?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :update, 2) and
      function_exported?(module, :render, 1)
  end
end
