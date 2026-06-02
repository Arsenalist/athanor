defmodule Athanor.Components.Formatting.EditorForm do
  @moduledoc """
  Shared formatting tab UI fragment. Stateless function component.

  Each component's editor form LC embeds this via
  `Athanor.Components.EditorForm.Shell`. On change, the formatting form
  fires `phx-change="update_props"` scoped to the parent LC — the LC's
  `handle_event("update_props", %{"formatting" => fmt} = _params, ...)`
  pattern-matches the formatting-only shape and writes it wholesale into
  `props["formatting"]`.

  Saved JSON shape (matches legacy):

      props["formatting"] = %{
        "text_color" => "#RRGGBB" | "",
        "background_color" => "#RRGGBB" | "",
        "border_color" => "#RRGGBB" | "",
        "padding_top" => integer,
        "padding_bottom" => integer,
        "padding_left" => integer,
        "padding_right" => integer,
        "margin_top" => integer,
        "margin_bottom" => integer,
        "margin_left" => integer,
        "margin_right" => integer,
        "border_radius" => integer,
        "border_width" => integer,
        "alignment" => "left" | "center" | "right"
      }
  """

  use Phoenix.Component

  attr(:form, :any, required: true, doc: "A Phoenix.HTML.Form built with `as: :formatting`")
  attr(:myself, :any, required: true, doc: "phx-target — the parent LC's myself")
  attr(:open_sections, :any, required: true, doc: "MapSet of section keys currently expanded")

  def editor_form(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-change="update_props"
      phx-target={@myself}
      data-testid="athanor-formatting-editor-form"
    >
      <div class="space-y-2 mt-4">
        <.section
          section="alignment"
          label="Alignment"
          icon="fa-align-center"
          open_sections={@open_sections}
          myself={@myself}
        >
          <label class="text-xs font-semibold">Horizontal</label>
          <select
            name="formatting[alignment]"
            class="select select-bordered select-sm w-full"
          >
            <option value="left" selected={@form[:alignment].value == "left"}>Left</option>
            <option value="center" selected={@form[:alignment].value == "center"}>Center</option>
            <option value="right" selected={@form[:alignment].value == "right"}>Right</option>
          </select>
        </.section>

        <.section
          section="colors"
          label="Colors"
          icon="fa-palette"
          open_sections={@open_sections}
          myself={@myself}
        >
          <div class="flex flex-col gap-3">
            <.color_swatch
              label="Text"
              name="formatting[text_color]"
              value={@form[:text_color].value}
              fallback="#000000"
            />
            <.color_swatch
              label="Background"
              name="formatting[background_color]"
              value={@form[:background_color].value}
              fallback="#ffffff"
            />
          </div>
        </.section>

        <.section
          section="padding"
          label="Padding"
          icon="fa-expand"
          open_sections={@open_sections}
          myself={@myself}
        >
          <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
            <.px_field form={@form} key={:padding_top} label="Top" />
            <.px_field form={@form} key={:padding_right} label="Right" />
            <.px_field form={@form} key={:padding_bottom} label="Bottom" />
            <.px_field form={@form} key={:padding_left} label="Left" />
          </div>
        </.section>

        <.section
          section="margin"
          label="Margin"
          icon="fa-arrows-alt"
          open_sections={@open_sections}
          myself={@myself}
        >
          <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
            <.px_field form={@form} key={:margin_top} label="Top" />
            <.px_field form={@form} key={:margin_right} label="Right" />
            <.px_field form={@form} key={:margin_bottom} label="Bottom" />
            <.px_field form={@form} key={:margin_left} label="Left" />
          </div>
        </.section>

        <.section
          section="borders"
          label="Borders"
          icon="fa-border-all"
          open_sections={@open_sections}
          myself={@myself}
        >
          <div class="grid grid-cols-3 gap-2">
            <.px_field form={@form} key={:border_radius} label="Radius" />
            <.px_field form={@form} key={:border_width} label="Width" />
            <div class="col-span-3">
              <.color_swatch
                label="Color"
                name="formatting[border_color]"
                value={@form[:border_color].value}
                fallback="#000000"
              />
            </div>
          </div>
        </.section>
      </div>
    </.form>
    """
  end

  # Color swatch with a Clear button. Pure client-side:
  #   - hidden input carries the submitted value (so clearing yields "")
  #   - native color picker is display-only (name-less); its `oninput` syncs
  #     the picked hex into the hidden input and dispatches a `change` event
  #     that bubbles up to the surrounding `<.form phx-change=...>`
  #   - Clear button uses `Phoenix.LiveView.JS.set_attribute` + `dispatch`
  #     to wipe the hidden input and refire the form's change handler
  attr(:label, :string, required: true)
  attr(:name, :string, required: true)
  attr(:value, :any, required: true, doc: "current color (hex) or nil/empty")
  attr(:fallback, :string, default: "#000000")

  defp color_swatch(assigns) do
    set? = is_binary(assigns.value) and assigns.value != ""
    hex = if set?, do: assigns.value, else: assigns.fallback
    hidden_id = "csw-" <> String.replace(assigns.name, ["[", "]", " "], "_")
    carried = if set?, do: assigns.value, else: ""

    sync_js =
      "var h=document.getElementById('#{hidden_id}');" <>
        "h.value=this.value;" <>
        "h.dispatchEvent(new Event('change',{bubbles:true}));"

    assigns =
      assigns
      |> Phoenix.Component.assign(:hex, hex)
      |> Phoenix.Component.assign(:set?, set?)
      |> Phoenix.Component.assign(:hidden_id, hidden_id)
      |> Phoenix.Component.assign(:carried, carried)
      |> Phoenix.Component.assign(:sync_js, sync_js)

    ~H"""
    <div class="space-y-1">
      <div class="flex items-center justify-between">
        <label class="block text-xs font-semibold text-base-content/70">{@label}</label>
        <button
          :if={@set?}
          type="button"
          phx-click={
            Phoenix.LiveView.JS.set_attribute({"value", ""}, to: "##{@hidden_id}")
            |> Phoenix.LiveView.JS.dispatch("change", to: "##{@hidden_id}", bubbles: true)
          }
          aria-label={"Clear " <> @label}
          class="text-[10px] text-base-content/40 hover:text-error cursor-pointer rounded px-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error/40"
        >
          Clear
        </button>
      </div>
      <div class="flex items-center gap-3">
        <input type="hidden" id={@hidden_id} name={@name} value={@carried} />
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

  attr(:section, :string, required: true)
  attr(:label, :string, required: true)
  attr(:icon, :string, required: true)
  attr(:open_sections, :any, required: true)
  attr(:myself, :any, required: true)
  slot(:inner_block, required: true)

  defp section(assigns) do
    ~H"""
    <div class="collapse collapse-arrow bg-base-200">
      <input
        type="checkbox"
        checked={MapSet.member?(@open_sections, @section)}
        phx-click="toggle_section"
        phx-value-section={@section}
        phx-target={@myself}
      />
      <div class="collapse-title font-medium">
        <i class={"fas mr-2 " <> @icon}></i> {@label}
      </div>
      <div class="collapse-content">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Initial set of expanded sections. Mirrors the legacy default of
  "colors" being open by default.
  """
  def default_open_sections, do: MapSet.new(["colors"])

  @doc """
  Toggle a section's expanded/collapsed state in the MapSet.
  """
  def toggle_section(open_sections, section) do
    if MapSet.member?(open_sections, section) do
      MapSet.delete(open_sections, section)
    else
      MapSet.put(open_sections, section)
    end
  end

  attr(:form, :any, required: true)
  attr(:key, :atom, required: true)
  attr(:label, :string, required: true)

  defp px_field(assigns) do
    ~H"""
    <div>
      <label class="text-xs font-semibold">{@label}</label>
      <input
        type="number"
        name={"formatting[#{@key}]"}
        value={@form[@key].value || 0}
        class="input input-bordered input-sm w-full"
        phx-debounce="300"
      />
    </div>
    """
  end

  @doc """
  Build a `Phoenix.HTML.Form` for the formatting fields, defaulted from the
  existing formatting map (or an empty map). Use `as: :formatting` so all
  fields submit under the `formatting[...]` namespace.

  Returns a tracked form ready to pass to `editor_form/1`.
  """
  def build_form(formatting) when is_map(formatting) do
    Phoenix.Component.to_form(
      %{
        "text_color" => formatting["text_color"] || "",
        "background_color" => formatting["background_color"] || "",
        "border_color" => formatting["border_color"] || "",
        "padding_top" => formatting["padding_top"] || 0,
        "padding_bottom" => formatting["padding_bottom"] || 0,
        "padding_left" => formatting["padding_left"] || 0,
        "padding_right" => formatting["padding_right"] || 0,
        "margin_top" => formatting["margin_top"] || 0,
        "margin_bottom" => formatting["margin_bottom"] || 0,
        "margin_left" => formatting["margin_left"] || 0,
        "margin_right" => formatting["margin_right"] || 0,
        "border_radius" => formatting["border_radius"] || 0,
        "border_width" => formatting["border_width"] || 0,
        "alignment" => formatting["alignment"] || "left"
      },
      as: :formatting
    )
  end

  def build_form(_), do: build_form(%{})

  @doc """
  Coerce the params map from a formatting-form phx-change into a clean
  prop-ready map (integer fields converted from strings). Matches the JSON
  shape on disk.
  """
  def coerce_params(params) when is_map(params) do
    %{
      "text_color" => params["text_color"] || "",
      "background_color" => params["background_color"] || "",
      "border_color" => params["border_color"] || "",
      "padding_top" => to_int(params["padding_top"]),
      "padding_bottom" => to_int(params["padding_bottom"]),
      "padding_left" => to_int(params["padding_left"]),
      "padding_right" => to_int(params["padding_right"]),
      "margin_top" => to_int(params["margin_top"]),
      "margin_bottom" => to_int(params["margin_bottom"]),
      "margin_left" => to_int(params["margin_left"]),
      "margin_right" => to_int(params["margin_right"]),
      "border_radius" => to_int(params["border_radius"]),
      "border_width" => to_int(params["border_width"]),
      "alignment" => params["alignment"] || "left"
    }
  end

  defp to_int(n) when is_integer(n), do: n
  defp to_int(""), do: 0
  defp to_int(nil), do: 0

  defp to_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_int(_), do: 0
end
