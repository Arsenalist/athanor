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
  - `:radio`    — radio-button group driven by the same `options:` keyword as
                  `:select` (static `[{label, value}, …]` list or arity-1 `Ctx`
                  function). Inline single-choice for small option sets; inputs
                  share the field `name`.
  - `:color`    — HTML5 `<input type="color">` (no JS dep)
  - `:checkbox` — `<input type="checkbox">` with hidden false-input so
                  unchecked submits as `"false"`
  - `:asset`    — host-agnostic uploaded-asset picker (image/pdf/video/…).
                  Renders neutral chrome (preview/chips + a choose/add
                  control) and a paste-a-URL fallback. Emits a fixed
                  `"athanor_asset_request"` event (no `phx-target`, so it
                  bubbles to the editor LiveView) — it never uploads or
                  browses itself. Opts: `accept:` (opaque hint forwarded to
                  the host), `multiple:` (gallery/multi-file), `min:`/`max:`
                  (forwarded, host-enforced). Value is an asset descriptor
                  map `%{"url" => ..., "name" => ..., "content_type" => ...}`
                  (single) or a list of them (`multiple: true`); opaque extra
                  keys are preserved. See `Athanor.Editor.AssetRequest` and
                  `c:Athanor.Editor.handle_asset_request/2`.
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

  attr(:module, :atom, required: true, doc: "component module whose fields/0 to render")
  attr(:props, :map, default: %{}, doc: "current node props")
  attr(:ctx, Athanor.Ctx, required: true)
  attr(:myself, :any, required: true, doc: "phx-target for the auto-form's parent LC")

  attr(:component_id, :string,
    default: "default",
    doc:
      "owning node id — namespaces custom field LC ids so multiple instances of the same component type don't collide on switch"
  )

  attr(:on_custom_change, :any,
    required: true,
    doc: "fn (key, value) -> any -- invoked by custom field LCs"
  )

  def render(assigns) do
    fields =
      assigns.module.resolve_fields(assigns.props, %{})
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
              component_id={@component_id}
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

  attr(:key, :string, required: true)
  attr(:type, :atom, required: true)
  attr(:opts, :any, required: true)
  attr(:props, :map, required: true)
  attr(:ctx, Athanor.Ctx, required: true)
  attr(:component_id, :string, default: "default")

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

  defp field(%{type: :radio} = assigns) do
    # Single-choice radio group. `options:` uses the SAME contract as :select
    # (static [{label, value}, ...] list OR an arity-1 fn of Ctx), resolved
    # lazily here. Inputs share `name={@key}` so the browser enforces single
    # selection and the fields form posts the checked value like any built-in.
    options = resolve_options(assigns.opts[:options], assigns)
    assigns = assign(assigns, :options, options)

    ~H"""
    <div>
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <div class="flex flex-col gap-1">
        <label :for={{label, value} <- @options} class="flex items-center gap-2 text-sm">
          <input
            type="radio"
            name={@key}
            value={value}
            checked={to_string(@props[@key]) == to_string(value)}
            class="radio radio-sm"
          />
          {label}
        </label>
      </div>
    </div>
    """
  end

  defp field(%{type: :color} = assigns) do
    raw = assigns.props[assigns.key]
    set? = is_binary(raw) and raw != ""
    hex = if set?, do: raw, else: "#000000"
    hidden_id = "csw-" <> String.replace(assigns.key, ["[", "]", " "], "_")
    carried = if set?, do: raw, else: ""

    sync_js =
      "var h=document.getElementById('#{hidden_id}');" <>
        "h.value=this.value;" <>
        "h.dispatchEvent(new Event('change',{bubbles:true}));"

    assigns =
      assigns
      |> assign(:hex, hex)
      |> assign(:set?, set?)
      |> assign(:hidden_id, hidden_id)
      |> assign(:carried, carried)
      |> assign(:sync_js, sync_js)

    ~H"""
    <div class="space-y-1">
      <div class="flex items-center justify-between">
        <label :if={@opts[:label]} class="block text-xs font-semibold text-base-content/70">
          {@opts[:label]}
        </label>
        <button
          :if={@set?}
          type="button"
          phx-click={
            Phoenix.LiveView.JS.set_attribute({"value", ""}, to: "##{@hidden_id}")
            |> Phoenix.LiveView.JS.dispatch("change", to: "##{@hidden_id}", bubbles: true)
          }
          aria-label={"Clear " <> (@opts[:label] || "color")}
          class="text-[10px] text-base-content/40 hover:text-error cursor-pointer rounded px-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error/40"
        >
          Clear
        </button>
      </div>
      <div class="flex items-center gap-3">
        <input type="hidden" id={@hidden_id} name={@key} value={@carried} />
        <input
          type="color"
          value={@hex}
          oninput={@sync_js}
          class="w-12 h-8 rounded border border-base-300 cursor-pointer"
        />
        <div class={[
          "flex-1 text-sm font-mono border rounded px-3 py-1.5",
          if(@set?,
            do: "bg-base-200 border-base-300 text-base-content/70",
            else: "bg-base-100 border-base-300/60 text-base-content/40 italic"
          )
        ]}>
          {if @set?, do: @hex, else: "Not set"}
        </div>
      </div>
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

  # ─── :asset ─────────────────────────────────────────────────────────────
  #
  # Host-agnostic uploaded-asset picker. Athanor renders neutral chrome and
  # emits a fixed `"athanor_asset_request"` event (no phx-target, so it
  # bubbles to the editor LiveView) — it never uploads or browses itself. The
  # value is an asset descriptor map `%{"url" => ..., "name" => ...,
  # "content_type" => ...}` (single) or a list of them (`multiple: true`). A
  # paste-a-URL input is the bare-minimal default when no host picker is wired.
  defp field(%{type: :asset} = assigns) do
    if assigns.opts[:multiple],
      do: asset_multiple(assigns),
      else: asset_single(assigns)
  end

  defp asset_multiple(assigns) do
    assigns = assign(assigns, :assets, List.wrap(assigns.props[assigns.key]))

    ~H"""
    <div data-testid="athanor-asset-field">
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <div class="flex flex-wrap gap-2 mb-2">
        <div
          :for={asset <- @assets}
          data-testid="athanor-asset-chip"
          class="flex items-center gap-1 bg-base-200 rounded px-2 py-1 text-xs"
        >
          <img
            :if={asset_image?(asset)}
            src={asset_url(asset)}
            class="w-6 h-6 rounded object-cover"
          />
          <i :if={!asset_image?(asset)} class="fa-regular fa-file" aria-hidden="true"></i>
          <span>{asset_name(asset)}</span>
          <button
            type="button"
            data-testid="athanor-asset-remove"
            phx-click="athanor_asset_remove"
            phx-value-node={@component_id}
            phx-value-key={@key}
            phx-value-url={asset_url(asset)}
            aria-label={"Remove " <> (asset_name(asset) || "asset")}
            class="text-base-content/40 hover:text-error cursor-pointer"
          >
            &times;
          </button>
        </div>
      </div>
      <button
        type="button"
        data-testid="athanor-asset-add"
        phx-click="athanor_asset_request"
        phx-value-node={@component_id}
        phx-value-key={@key}
        phx-value-accept={asset_accept_attr(@opts[:accept])}
        phx-value-multiple="true"
        phx-value-max={@opts[:max]}
        phx-value-min={@opts[:min]}
        class="btn btn-sm btn-outline"
      >
        Add
      </button>
    </div>
    """
  end

  defp asset_single(assigns) do
    value = assigns.props[assigns.key]

    assigns =
      assigns
      |> assign(:url, asset_url(value))
      |> assign(:name, asset_name(value))
      |> assign(:image?, asset_image?(value))

    ~H"""
    <div data-testid="athanor-asset-field">
      <label :if={@opts[:label]} class="text-xs font-semibold">{@opts[:label]}</label>
      <div
        :if={@url}
        data-testid="athanor-asset-preview"
        class="mb-2 flex items-center gap-2"
      >
        <img :if={@image?} src={@url} class="w-auto h-24 rounded-lg border border-base-300 object-contain" />
        <span :if={!@image?} class="flex items-center gap-2 text-sm">
          <i class="fa-regular fa-file" aria-hidden="true"></i>{@name}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <input
          type="text"
          name={@key}
          value={@url || ""}
          placeholder={@opts[:placeholder] || "Paste a URL…"}
          class="input input-bordered input-sm flex-1"
          phx-debounce={@opts[:debounce] || "300"}
        />
        <button
          type="button"
          data-testid="athanor-asset-choose"
          phx-click="athanor_asset_request"
          phx-value-node={@component_id}
          phx-value-key={@key}
          phx-value-accept={asset_accept_attr(@opts[:accept])}
          phx-value-max={@opts[:max]}
          phx-value-min={@opts[:min]}
          class="btn btn-sm btn-outline"
        >
          Choose
        </button>
      </div>
    </div>
    """
  end

  attr(:key, :string, required: true)
  attr(:opts, :any, required: true)
  attr(:props, :map, required: true)
  attr(:ctx, Athanor.Ctx, required: true)
  attr(:component_id, :string, required: true)
  attr(:on_change, :any, required: true)

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

  # ─── helpers ───────────────────────────────────────────────────────────

  defp resolve_options(opts, assigns) when is_function(opts, 1) do
    opts.(assigns[:ctx] || Athanor.Ctx.new())
  rescue
    _ -> []
  end

  defp resolve_options(opts, _assigns) when is_list(opts), do: opts
  defp resolve_options(_, _), do: []

  # ─── :asset helpers ─────────────────────────────────────────────────────
  #
  # An asset value is a descriptor map (`%{"url" => ...}`) but a bare URL
  # string is tolerated for back-compat / the paste fallback. Athanor reads
  # only `url`/`name`/`content_type`; all other descriptor keys are opaque.

  @image_exts ~w(.jpg .jpeg .png .gif .webp .avif .svg .bmp .heic)

  @doc false
  def asset_url(value) when is_binary(value), do: value
  def asset_url(%{"url" => url}) when is_binary(url), do: url
  def asset_url(_), do: nil

  @doc false
  def asset_name(%{"name" => name}) when is_binary(name) and name != "", do: name

  def asset_name(value) do
    case asset_url(value) do
      nil -> nil
      url -> url |> String.split("/") |> List.last()
    end
  end

  @doc false
  def asset_image?(%{"content_type" => "image/" <> _}), do: true

  def asset_image?(%{"content_type" => ct}) when is_binary(ct) and ct != "", do: false

  def asset_image?(value) do
    case asset_url(value) do
      nil -> false
      url -> String.downcase(Path.extname(url)) in @image_exts
    end
  end

  # accept hint is forwarded opaque; lists are comma-joined for transport.
  defp asset_accept_attr(nil), do: nil
  defp asset_accept_attr(accept) when is_binary(accept), do: accept
  defp asset_accept_attr(accept) when is_list(accept), do: Enum.join(accept, ",")
  defp asset_accept_attr(_), do: nil

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
end
