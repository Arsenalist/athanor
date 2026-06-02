defmodule Athanor.Components.Columns do
  @moduledoc """
  Multi-column layout container — library-native Athanor component.

  Configurable via the editor's AutoEditorForm:
  - `num_zones`: 2..4 columns
  - `vertical_align`: top / center / bottom / stretch
  - `width_distribution`: per-num_zones option set (50/50, 66/33, ...)

  Storage shape:
      %{
        "num_zones"          => "2",
        "zone_names"         => ["one", "two"],
        "zones"              => %{"one" => [...nodes], "two" => [...nodes]},
        "vertical_align"     => "top",
        "width_distribution" => "equal"
      }

  Child nodes inside each zone are rendered via
  `Athanor.Renderer.node_component/1` — so any registered Athanor or
  legacy component can live inside Columns.

  ## Editor canvas chrome

  When `ctx.edit_mode?` is true, `render(:live)` adds dashed-border
  zone borders and an "Add Component" button per zone. The button's
  phx-click is built from `ctx.add_component_callback.(zone_name)` —
  the consumer LiveView provides this callback (typically a
  `Phoenix.LiveView.JS.push(...)` command) so the consumer's
  palette modal is what opens; the library never assumes what
  components are available.
  """

  use Athanor.Component
  use Phoenix.Component

  alias Athanor.Renderer

  @min_zones 2
  @max_zones 4

  @zone_name_lookup %{
    1 => ["one"],
    2 => ["one", "two"],
    3 => ["one", "two", "three"],
    4 => ["one", "two", "three", "four"]
  }

  @width_distributions %{
    2 => [
      %{label: "Equal (50/50)", value: "equal", classes: ["w-1/2", "w-1/2"]},
      %{label: "Left wider (66/33)", value: "66-33", classes: ["w-2/3", "w-1/3"]},
      %{label: "Right wider (33/66)", value: "33-66", classes: ["w-1/3", "w-2/3"]},
      %{label: "Sidebar left (25/75)", value: "25-75", classes: ["w-1/4", "w-3/4"]},
      %{label: "Sidebar right (75/25)", value: "75-25", classes: ["w-3/4", "w-1/4"]}
    ],
    3 => [
      %{label: "Equal (33/33/33)", value: "equal", classes: ["w-1/3", "w-1/3", "w-1/3"]},
      %{label: "Center emphasis (25/50/25)", value: "25-50-25",
        classes: ["w-1/4", "w-1/2", "w-1/4"]},
      %{label: "Left emphasis (50/25/25)", value: "50-25-25",
        classes: ["w-1/2", "w-1/4", "w-1/4"]},
      %{label: "Right emphasis (25/25/50)", value: "25-25-50",
        classes: ["w-1/4", "w-1/4", "w-1/2"]}
    ],
    4 => [
      %{label: "Equal (25/25/25/25)", value: "equal",
        classes: ["w-1/4", "w-1/4", "w-1/4", "w-1/4"]}
    ]
  }

  @vertical_align_options [
    {"Top", "top"},
    {"Center", "center"},
    {"Bottom", "bottom"},
    {"Stretch", "stretch"}
  ]

  @vertical_align_class %{
    "top" => "items-start",
    "center" => "items-center",
    "bottom" => "items-end",
    "stretch" => "items-stretch"
  }

  @impl Athanor.Component
  def metadata do
    %{
      type: "columns",
      label: "Columns",
      icon: "fa-columns",
      category: :layout,
      description: "Multi-column layout"
    }
  end

  @impl Athanor.Component
  def default_props do
    %{
      "num_zones" => "2",
      "zone_names" => Map.fetch!(@zone_name_lookup, 2),
      "zones" => %{"one" => [], "two" => []},
      "vertical_align" => "top",
      "width_distribution" => "equal"
    }
  end

  @impl Athanor.Component
  def required_props, do: ["zone_names"]

  @impl Athanor.Component
  def validate(props) do
    case props["zone_names"] do
      list when is_list(list) and length(list) in @min_zones..@max_zones ->
        :ok

      _ ->
        {:error,
         {:invalid_zone_count, "expected #{@min_zones}..#{@max_zones} zones"}}
    end
  end

  @impl Athanor.Component
  def child_zones(node) do
    Map.get(node["props"] || %{}, "zones", %{})
  end

  @impl Athanor.Component
  def fields do
    [
      {"num_zones", :select,
       label: "Number of Columns",
       options: Enum.map(@min_zones..@max_zones, fn n -> {"#{n}", "#{n}"} end)},
      {"vertical_align", :select,
       label: "Vertical Align", options: @vertical_align_options},
      # width_distribution options are populated dynamically by
      # resolve_fields/2 based on the current num_zones.
      {"width_distribution", :select, label: "Column Widths", options: []}
    ]
  end

  @impl Athanor.Component
  def resolve_fields(props, _opts) do
    n = num_zones_int(props["num_zones"])
    wd_opts = width_distribution_options(n)

    Enum.map(fields(), fn
      {"width_distribution", :select, opts} ->
        {"width_distribution", :select, Keyword.put(opts, :options, wd_opts)}

      f ->
        f
    end)
  end

  @impl Athanor.Component
  def resolve_data(old, new) do
    if old["num_zones"] != new["num_zones"] do
      n = num_zones_int(new["num_zones"])
      names = Map.get(@zone_name_lookup, n, [])
      old_zones = new["zones"] || %{}

      zones =
        Enum.reduce(names, %{}, fn name, acc ->
          Map.put(acc, name, Map.get(old_zones, name, []))
        end)

      new
      |> Map.put("zone_names", names)
      |> Map.put("zones", zones)
      |> Map.put("width_distribution", "equal")
    else
      new
    end
  end

  @impl Athanor.Component
  def render(:live, node, ctx) do
    props = node["props"] || %{}
    zone_names = props["zone_names"] || []
    zones = props["zones"] || %{}
    align_class = Map.get(@vertical_align_class, props["vertical_align"], "items-start")
    distribution = props["width_distribution"] || "equal"
    classes = width_classes(length(zone_names), distribution)

    assigns = %{
      ctx: ctx,
      zone_names: zone_names,
      zones: zones,
      align_class: align_class,
      width_classes: classes,
      edit_mode?: ctx.edit_mode? == true
    }

    ~H"""
    <div class={"flex gap-4 flex-col @md:flex-row w-full #{@align_class}"}>
      <div
        :for={{zone_name, idx} <- Enum.with_index(@zone_names)}
        class={zone_wrapper_class(@edit_mode?, Enum.at(@width_classes, idx, "flex-1"))}
      >
        <Renderer.node_component
          :for={child <- Map.get(@zones, zone_name, [])}
          node={child}
          ctx={@ctx}
          edit_mode={@edit_mode?}
          show_config={false}
        />

        <button
          :if={@edit_mode? and @ctx.add_component_callback != nil}
          type="button"
          phx-click={@ctx.add_component_callback.(zone_name)}
          class="mx-auto block text-center text-gray-500 cursor-pointer border-2 border-gray-300 rounded-lg p-1 mt-4 hover:bg-gray-100 w-40"
        >
          <i class="fas fa-plus mr-1"></i> Add Component
        </button>
      </div>
    </div>
    """
  end

  defp zone_wrapper_class(true, width_class),
    do: "@md:#{width_class} min-h-[200px] border-2 border-dashed border-gray-300 rounded-lg p-4"

  defp zone_wrapper_class(false, width_class), do: "@md:#{width_class}"

  defp width_distribution_options(n) do
    @width_distributions
    |> Map.get(n, [])
    |> Enum.map(fn %{label: l, value: v} -> {l, v} end)
  end

  defp width_classes(n, distribution) do
    options = Map.get(@width_distributions, n, [])
    option = Enum.find(options, fn o -> o.value == distribution end) || List.first(options)

    case option do
      nil -> List.duplicate("flex-1", n)
      %{classes: c} -> c
    end
  end

  defp num_zones_int(value) when is_integer(value), do: clamp_zone_count(value)

  defp num_zones_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> clamp_zone_count(n)
      _ -> @min_zones
    end
  end

  defp num_zones_int(_), do: @min_zones

  defp clamp_zone_count(n) when n < @min_zones, do: @min_zones
  defp clamp_zone_count(n) when n > @max_zones, do: @max_zones
  defp clamp_zone_count(n), do: n
end
