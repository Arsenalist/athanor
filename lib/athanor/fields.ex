defmodule Athanor.Fields do
  @moduledoc """
  Auto-renders a component's editable inputs from its `fields/0` schema.

  Used by `Athanor.AutoEditorForm` to fill the Component tab of the
  configure panel. Stateless function component — the LC machinery
  (state, phx-change routing, custom-field on_change plumbing) lives in
  `Athanor.AutoEditorForm`.

  ## Built-in types

  - `:text`     — `<input type="text">`
  - `:textarea` — `<textarea>`
  - `:number`   — `<input type="number">` with optional `min`/`max`
  - `:select`   — `<select>` driven by `options:` keyword
  - `:color`    — HTML5 `<input type="color">` (no JS dep)
  - `:checkbox` — `<input type="checkbox">` with hidden false-input so
                  unchecked submits as `"false"`
  - `:custom`   — mounts `<.live_component module={opts[:module]}>`
                  matching `Athanor.Field` behaviour

  ## Conditional fields

  Any field opts list may include `if: fn props -> boolean end`. When the
  function returns false against the current props, the field is omitted
  from the render. Re-evaluated each render, so a sibling field that
  changes via `update_props` immediately shows/hides dependents.

  ## Form layout

  Built-in inputs live inside ONE `<.form phx-change="update_props"
  phx-target={@myself}>` so a single phx-change submits all fields'
  current values as form params. Custom fields render OUTSIDE the form
  (they have their own state and `on_change` callback).
  """

  use Phoenix.Component

  attr :module, :atom, required: true, doc: "component module whose fields/0 to render"
  attr :props, :map, default: %{}, doc: "current node props"
  attr :ctx, Athanor.Ctx, required: true
  attr :myself, :any, required: true, doc: "phx-target for the auto-form's parent LC"

  attr :component_id, :string,
    default: "default",
    doc: "owning node id — namespaces custom field LC ids so multiple instances of the same component type don't collide on switch"

  attr :on_custom_change, :any,
    required: true,
    doc: "fn (key, value) -> any -- invoked by custom field LCs"

  def render(assigns) do
    fields =
      assigns.module.fields()
      |> Enum.filter(&visible?(&1, assigns.props))

    {custom_fields, builtin_fields} =
      Enum.split_with(fields, fn {_k, type, _opts} -> type == :custom end)

    assigns =
      assigns
      |> assign(:builtin_fields, builtin_fields)
      |> assign(:custom_fields, custom_fields)

    ~H"""
    <div data-testid="athanor-fields">
      <%= if @builtin_fields != [] do %>
        <form
          phx-change="update_props"
          phx-target={@myself}
          data-testid="athanor-fields-form"
        >
          <div class="flex flex-col gap-2">
            <.field
              :for={{key, type, opts} <- @builtin_fields}
              key={key}
              type={type}
              opts={opts}
              props={@props}
              ctx={@ctx}
            />
          </div>
        </form>
      <% end %>

      <%= if @custom_fields != [] do %>
        <div class="flex flex-col gap-2 mt-3" data-testid="athanor-fields-custom">
          <.custom_field
            :for={{key, :custom, opts} <- @custom_fields}
            key={key}
            opts={opts}
            props={@props}
            ctx={@ctx}
            component_id={@component_id}
            on_change={@on_custom_change}
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :type, :atom, required: true
  attr :opts, :any, required: true
  attr :props, :map, required: true
  attr :ctx, Athanor.Ctx, required: true

  defp field(%{type: :text} = assigns) do
    ~H"""
    <div>
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <input
        type="text"
        name={@key}
        value={@props[@key] || ""}
        placeholder={@opts[:placeholder] || ""}
        class="input input-bordered input-sm w-full"
        phx-debounce={@opts[:debounce] || "300"}
      />
    </div>
    """
  end

  defp field(%{type: :textarea} = assigns) do
    ~H"""
    <div>
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <textarea
        name={@key}
        placeholder={@opts[:placeholder] || ""}
        class="textarea textarea-bordered textarea-sm w-full"
        phx-debounce={@opts[:debounce] || "300"}
      >{@props[@key] || ""}</textarea>
    </div>
    """
  end

  defp field(%{type: :number} = assigns) do
    ~H"""
    <div>
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <input
        type="number"
        name={@key}
        value={@props[@key] || 0}
        min={@opts[:min]}
        max={@opts[:max]}
        class="input input-bordered input-sm w-full"
        phx-debounce={@opts[:debounce] || "300"}
      />
    </div>
    """
  end

  defp field(%{type: :select} = assigns) do
    # options: may be a static [{label, value}, ...] list OR a function
    # of arity 1 receiving the Ctx (so consumer can hit account/brand-
    # scoped data sources at editor-render time). Evaluated lazily here.
    options = resolve_options(assigns.opts[:options], assigns)
    assigns = assigns |> assign(:options, options)

    ~H"""
    <div>
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <select name={@key} class="select select-bordered select-sm w-full">
        <option :if={@opts[:prompt]} value="" selected={@props[@key] in [nil, ""]}>
          {@opts[:prompt]}
        </option>
        <option
          :for={{label, value} <- @options}
          value={value}
          selected={to_string(@props[@key]) == to_string(value)}
        >
          {label}
        </option>
      </select>
    </div>
    """
  end

  defp resolve_options(opts, assigns) when is_function(opts, 1) do
    opts.(assigns[:ctx] || Athanor.Ctx.new())
  rescue
    _ -> []
  end

  defp resolve_options(opts, _assigns) when is_list(opts), do: opts
  defp resolve_options(_, _), do: []

  defp visible?({_k, _t, opts}, props) do
    case opts[:if] do
      nil ->
        true

      fun when is_function(fun, 1) ->
        try do
          !!fun.(props)
        rescue
          _ -> true
        end

      _ ->
        true
    end
  end

  defp field(%{type: :color} = assigns) do
    ~H"""
    <div>
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <input
        type="color"
        name={@key}
        value={@props[@key] || "#000000"}
        class="input input-bordered input-sm w-full h-10"
      />
    </div>
    """
  end

  defp field(%{type: :checkbox} = assigns) do
    ~H"""
    <div>
      <label class="flex items-center gap-2 text-xs font-semibold">
        <input type="hidden" name={@key} value="false" />
        <input
          type="checkbox"
          name={@key}
          value="true"
          checked={!!@props[@key]}
          class="checkbox checkbox-sm"
        />
        {@opts[:label]}
      </label>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :opts, :any, required: true
  attr :props, :map, required: true
  attr :ctx, Athanor.Ctx, required: true
  attr :component_id, :string, required: true
  attr :on_change, :any, required: true

  defp custom_field(assigns) do
    assigns =
      assign(
        assigns,
        :lc_id,
        "athanor-custom-field-#{assigns.component_id}-#{assigns.key}"
      )

    ~H"""
    <div>
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <.live_component
        module={@opts[:module]}
        id={@lc_id}
        value={@props[@key]}
        on_change={fn val -> @on_change.(@key, val) end}
        ctx={@ctx}
        label={@opts[:label]}
        opts={@opts}
      />
    </div>
    """
  end
end
