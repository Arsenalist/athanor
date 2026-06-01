defmodule Athanor.Registry do
  @moduledoc """
  Open registry mapping a node's `type` string to its component module.

  ## Configuration

      config :athanor,
        components: [MyApp.Components.Foo, MyApp.Components.Bar],
        fallback_resolver: {MyApp.LegacyResolver, :resolve_type}

  `:components` is a list of modules that implement `Athanor.Component`.
  Lookup matches `node["type"]` against each module's `metadata().type`.

  `:fallback_resolver` is an optional `{module, function}` tuple. When a
  type is not found in `:components`, the resolver is called as
  `module.function(type_string)` and may return a module or `nil`. This
  lets a consumer app keep its existing component dispatch wired in
  during a gradual migration.

  Both keys are read at call time via `Application.get_env/2`, so test
  setup can swap them per scenario.
  """

  @doc """
  Return the module registered for `type`, or `nil`.
  """
  def lookup(type) when is_binary(type) do
    case Enum.find(all(), fn mod -> mod.metadata().type == type end) do
      nil -> fallback(type)
      mod -> mod
    end
  end

  @doc """
  Return the metadata for the module registered for `type`, or `nil`.
  """
  def metadata_for(type) when is_binary(type) do
    case lookup(type) do
      nil -> nil
      mod -> mod.metadata()
    end
  end

  @doc """
  Return the configured list of component modules.
  """
  def all do
    Application.get_env(:athanor, :components, [])
  end

  @doc """
  Return a flat list of `metadata/0` maps for every registered Athanor
  component. Convenient for editor palettes and similar UI surfaces that
  want to iterate components by display info.
  """
  def components_metadata do
    Enum.map(all(), fn mod -> mod.metadata() end)
  end

  defp fallback(type) do
    case Application.get_env(:athanor, :fallback_resolver) do
      nil -> nil
      {mod, fun} -> apply(mod, fun, [type])
    end
  end
end
