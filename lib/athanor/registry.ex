defmodule Athanor.Registry do
  @moduledoc """
  Named registries mapping a node's `type` string to its component module.

  A host app almost always ends up with more than one palette. A page builder
  and, say, a broadcast-overlay editor both want Athanor components, but neither
  wants the other's modules showing up in its palette or resolvable from its
  trees. So a registry is always named, and every lookup says which one it means.

  ## Configuration

      config :athanor, :registries,
        page_builder: [
          components: [MyApp.Components.Hero, MyApp.Components.Card],
          fallback_resolver: {MyApp.LegacyResolver, :resolve_type}
        ],
        channel_overlays: [
          components: [MyApp.Overlays.Text, MyApp.Overlays.MarqueeText]
        ]

  `:components` is a list of modules implementing `Athanor.Component`. Lookup
  matches `node["type"]` against each module's `metadata().type`.

  `:fallback_resolver` is an optional `{module, function}` tuple, scoped to its
  registry. When a type is not found in that registry's `:components`, the
  resolver is called as `module.function(type_string)` and may return a module
  or `nil` — how a consumer keeps existing dispatch wired in during a gradual
  migration.

  Config is read at call time via `Application.get_env/2`, so test setup can
  swap registries per scenario.

  ## Naming a registry at each call site

  Rendering reads the name off `Athanor.Ctx` (`ctx.registry`), which
  `Athanor.Renderer` threads through dispatch. Editor consumers declare it once
  as the required `registry:` option of `use Athanor.Editor.Live`.

  ## Errors are loud

  An unknown registry name raises rather than resolving to an empty list: a
  typo that silently turned every component into "Unknown component type" would
  be far harder to diagnose than a crash naming the registries that do exist.
  """

  @doc """
  Return the module registered for `type` in `registry`, or `nil`.
  """
  def lookup(registry, type) when is_binary(type) do
    case Enum.find(all(registry), fn mod -> mod.metadata().type == type end) do
      nil -> fallback(registry, type)
      mod -> mod
    end
  end

  @doc """
  Return the metadata for the module registered for `type` in `registry`, or
  `nil`.
  """
  def metadata_for(registry, type) when is_binary(type) do
    case lookup(registry, type) do
      nil -> nil
      mod -> mod.metadata()
    end
  end

  @doc """
  Return `registry`'s configured component modules.
  """
  def all(registry) do
    Keyword.get(config(registry), :components, [])
  end

  @doc """
  Return a flat list of `metadata/0` maps for every component in `registry`.
  Convenient for editor palettes and similar UI surfaces that iterate components
  by display info.
  """
  def components_metadata(registry) do
    Enum.map(all(registry), fn mod -> mod.metadata() end)
  end

  @doc """
  Return the names of every configured registry.
  """
  def registries, do: Keyword.keys(registries_config())

  defp fallback(registry, type) do
    case Keyword.get(config(registry), :fallback_resolver) do
      nil -> nil
      {mod, fun} -> apply(mod, fun, [type])
    end
  end

  defp config(registry) when is_atom(registry) and not is_nil(registry) do
    case Keyword.fetch(registries_config(), registry) do
      {:ok, config} when is_list(config) ->
        config

      {:ok, other} ->
        raise ArgumentError,
              "Athanor registry #{inspect(registry)} must be configured as a keyword " <>
                "list, got: #{inspect(other)}"

      :error ->
        raise ArgumentError,
              "unknown Athanor registry #{inspect(registry)}. Configured registries: " <>
                "#{inspect(registries())}. Add it under `config :athanor, :registries`."
    end
  end

  defp config(nil) do
    raise ArgumentError,
          "no Athanor registry given. Set `ctx.registry` when rendering, or pass " <>
            "`registry:` to `use Athanor.Editor.Live`. Configured registries: " <>
            "#{inspect(registries())}."
  end

  defp config(other) do
    raise ArgumentError, "Athanor registry must be an atom, got: #{inspect(other)}"
  end

  # Reading the config is also where the pre-registries shape gets caught. The
  # flat keys are gone rather than shimmed, and a host that still sets them
  # would otherwise see an empty palette with no explanation.
  defp registries_config do
    if legacy_key =
         Enum.find([:components, :fallback_resolver], &Application.get_env(:athanor, &1)) do
      raise ArgumentError, legacy_config_message(legacy_key)
    end

    Application.get_env(:athanor, :registries, [])
  end

  defp legacy_config_message(key) do
    """
    `config :athanor, #{inspect(key)}` is no longer supported — Athanor registries are named.

    Move it under `:registries`:

        config :athanor, :registries,
          page_builder: [
            components: [...],
            fallback_resolver: {Mod, :fun}
          ]

    and name the registry at each call site: `registry:` on
    `use Athanor.Editor.Live`, and `ctx.registry` when rendering a tree.
    """
  end
end
