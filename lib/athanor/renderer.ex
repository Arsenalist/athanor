defmodule Athanor.Renderer do
  @moduledoc """
  Unified render dispatch over an `Athanor.Tree`.

  Iterates `tree["content"]`. For each node:

  1. Resolves the component module via `Athanor.Registry.lookup/1`.
  2. If the module exports `render/3` (new `Athanor.Component` path), calls
     `module.render(:live, node, ctx)`.
  3. Otherwise dispatches via the configured `:legacy_adapter` — see
     `Application.put_env(:athanor, :legacy_adapter, {Mod, :fun})`. The
     adapter receives `(component_module, assigns)` and returns renderable
     HEEx, which is embedded inline.
  4. For legacy modules implementing `has_required_props?/1`, the node is
     SKIPPED entirely (no output) when `edit_mode=false` and required props
     are missing — matching the storefront's pre-Athanor behaviour.
  5. If the type cannot be resolved at all, renders an inline developer
     placeholder. Does NOT crash the parent LiveView.

  Both editor-canvas and storefront-page call sites converge here, so a
  per-component cutover only needs to change the component module — the
  dispatch logic is shared.
  """

  use Phoenix.Component

  alias Athanor.Registry

  attr(:tree, :map, required: true, doc: "An `Athanor.Tree`-shaped map: %{\"content\" => [...]}")
  attr(:ctx, Athanor.Ctx, required: true)
  attr(:edit_mode, :boolean, default: false)
  attr(:show_config, :boolean, default: false)
  attr(:selected_component_id, :string, default: nil)

  @doc """
  Render every root node in the tree.

  Output mirrors the pre-Athanor storefront renderer layout: a single
  `flex flex-col gap-4` wrapper, with each node's rendered output directly
  inside (no per-node wrapping div).
  """
  def tree(assigns) do
    nodes = (assigns.tree || %{}) |> Map.get("content", []) |> List.wrap()
    assigns = assign(assigns, :nodes, nodes)

    ~H"""
    <div class="flex flex-col gap-4">
      <.node_component
        :for={node <- @nodes}
        node={node}
        ctx={@ctx}
        edit_mode={@edit_mode}
        show_config={@show_config}
        selected_component_id={@selected_component_id}
      />
    </div>
    """
  end

  attr(:node, :map, required: true)
  attr(:ctx, Athanor.Ctx, required: true)
  attr(:edit_mode, :boolean, default: false)
  attr(:show_config, :boolean, default: false)
  attr(:selected_component_id, :string, default: nil)

  @doc """
  Render a single node. Named `node_component` to avoid colliding with
  `Kernel.node/1`.
  """
  def node_component(assigns) do
    module = Registry.lookup(assigns.node["type"])
    assigns = assign(assigns, :module, module)

    cond do
      is_nil(module) ->
        unknown_type(assigns)

      skipped_legacy?(module, assigns) ->
        empty(assigns)

      has_fields?(module, assigns) ->
        fields_path(assigns)

      editor_form_for(module, assigns) ->
        editor_form_path(assigns)

      needs_configure_placeholder?(module, assigns) ->
        configure_placeholder(assigns)

      function_exported?(module, :render, 3) ->
        new_path(assigns)

      true ->
        legacy_path(assigns)
    end
  end

  # Edit-mode preview (canvas) for a node that fails validation OR has
  # `has_required_props?/1` returning false. Without this gate, the
  # component's render(:live) gets called with empty/required-missing
  # props and typically crashes (e.g. legacy Venue LC blows up on
  # `get_venue("")`). Top-level nodes are gated by the consumer's
  # ComponentListRenderer placeholder; this catches NESTED nodes
  # (e.g. children of `Athanor.Components.Columns` zones).
  defp needs_configure_placeholder?(module, %{edit_mode: true} = assigns) do
    props = assigns.node["props"] || %{}

    cond do
      function_exported?(module, :validate, 1) and module.validate(props) != :ok ->
        true

      function_exported?(module, :has_required_props?, 1) ->
        not (!!module.has_required_props?(props))

      true ->
        false
    end
  end

  defp needs_configure_placeholder?(_module, _assigns), do: false

  defp configure_placeholder(assigns) do
    ~H"""
    <div
      data-testid="athanor-configure-placeholder"
      class="bg-yellow-50 border border-yellow-200 rounded p-3 text-center text-sm text-yellow-800"
    >
      <i class="fas fa-cog mr-1"></i> Configure this component
    </div>
    """
  end

  # New-path detection for fields/0. Only fires in config mode. Empty list
  # (the default injected by `use Athanor.Component`) is treated as "no
  # fields declared" so legacy components keep flowing through editor_form/0.
  defp has_fields?(module, %{edit_mode: true, show_config: true}) do
    function_exported?(module, :fields, 0) and module.fields() != []
  end

  defp has_fields?(_module, _assigns), do: false

  defp fields_path(assigns) do
    assigns =
      assigns
      |> assign(:lc_id, "athanor-auto-form-" <> assigns.node["id"])
      |> assign(:component_module, assigns.module)

    ~H"""
    <.live_component
      module={Athanor.AutoEditorForm}
      id={@lc_id}
      component_id={@node["id"]}
      component_module={@component_module}
      props={@node["props"]}
      ctx={@ctx}
    />
    """
  end

  # Returns the editor_form module if applicable for the current dispatch
  # mode (edit_mode + show_config + module exports editor_form/0 + result is
  # non-nil); otherwise nil.
  defp editor_form_for(module, %{edit_mode: true, show_config: true}) do
    if function_exported?(module, :editor_form, 0) do
      case module.editor_form() do
        nil -> nil
        form_module -> form_module
      end
    end
  end

  defp editor_form_for(_module, _assigns), do: nil

  defp editor_form_path(assigns) do
    form_module = editor_form_for(assigns.module, assigns)

    assigns =
      assign(assigns,
        form_module: form_module,
        lc_id: "athanor-editor-form-" <> assigns.node["id"]
      )

    ~H"""
    <.live_component
      module={@form_module}
      id={@lc_id}
      component_id={@node["id"]}
      props={@node["props"]}
      ctx={@ctx}
      account_id={@ctx.account_id}
      brand_id={@ctx.brand_id}
      user_id={@ctx.user_id}
      api_token={@ctx.api_token}
    />
    """
  end

  defp skipped_legacy?(module, %{edit_mode: false} = assigns) do
    skipped_by_legacy?(module, assigns) or skipped_by_athanor_validate?(module, assigns)
  end

  defp skipped_legacy?(_module, _assigns), do: false

  # Legacy `has_required_props?/1` is documented to return a boolean,
  # but several existing impls return truthy non-booleans (e.g. an integer
  # id via `props["a"] && props["b"]`). The pre-Athanor renderer used
  # `if`/`unless`, which accepts any truthy/falsy. Use `!` here to preserve
  # that tolerance rather than crashing on `not 6`.
  defp skipped_by_legacy?(module, assigns) do
    function_exported?(module, :has_required_props?, 1) and
      !module.has_required_props?(assigns.node["props"])
  end

  # Athanor components implement `validate/1`. Storefront skips when
  # validation fails (mirrors the legacy skip-when-missing-required behavior).
  # Gated on the module actually implementing `Athanor.Component`, because
  # some legacy components also expose a `validate/1` with a different
  # contract (e.g. `Columns.validate/1` returns `{:ok, props}` on success).
  defp skipped_by_athanor_validate?(module, assigns) do
    implements_athanor_component?(module) and
      function_exported?(module, :validate, 1) and
      module.validate(assigns.node["props"] || %{}) != :ok
  end

  defp implements_athanor_component?(module) do
    case module.module_info(:attributes) do
      attrs when is_list(attrs) ->
        Athanor.Component in Keyword.get(attrs, :behaviour, [])

      _ ->
        false
    end
  rescue
    _ -> false
  end

  defp empty(assigns) do
    ~H""
  end

  defp new_path(assigns) do
    rendered = assigns.module.render(:live, assigns.node, assigns.ctx)
    assigns = assign(assigns, :rendered, rendered)

    ~H"""
    {@rendered}
    """
  end

  defp legacy_path(assigns) do
    case Application.get_env(:athanor, :legacy_adapter) do
      nil ->
        unimplemented_legacy(assigns)

      {mod, fun} ->
        rendered = apply(mod, fun, [assigns.module, assigns])
        assigns = assign(assigns, :rendered, rendered)

        ~H"""
        {@rendered}
        """
    end
  end

  defp unknown_type(assigns) do
    ~H"""
    <div
      data-athanor-unknown-type={@node["type"]}
      style="padding: 0.5rem; border: 1px dashed #c00; color: #c00;"
    >
      Unknown component type: {@node["type"]}
    </div>
    """
  end

  defp unimplemented_legacy(assigns) do
    ~H"""
    <div
      data-athanor-legacy-unwired={@node["type"]}
      style="padding: 0.5rem; border: 1px dashed #c80; color: #c80;"
    >
      Legacy component '{@node["type"]}' resolved but no :legacy_adapter configured.
    </div>
    """
  end
end
