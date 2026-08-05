defmodule Athanor.Test.RegistryHelpers do
  @moduledoc false
  # Registries are application config, so every test that needs one has to set
  # it and put it back. `@test_registry` is the name suites use unless they are
  # specifically about scoping between registries.

  @test_registry :test

  @doc "The registry name tests use by default."
  def test_registry, do: @test_registry

  @doc """
  Configure `@test_registry` with `components` (and optionally a
  `fallback_resolver`), restoring whatever was there when the test ends.

  Call from `setup` — it registers its own `on_exit`.
  """
  def put_test_registry(components, opts \\ []) do
    put_registry(@test_registry, components, opts)
  end

  @doc "Same, under an explicitly named registry."
  def put_registry(name, components, opts \\ []) do
    original = Application.get_env(:athanor, :registries)

    config =
      case Keyword.fetch(opts, :fallback_resolver) do
        {:ok, resolver} -> [components: components, fallback_resolver: resolver]
        :error -> [components: components]
      end

    registries = Keyword.put(original || [], name, config)
    Application.put_env(:athanor, :registries, registries)

    ExUnit.Callbacks.on_exit(fn -> restore(original) end)

    :ok
  end

  @doc "Configure several registries at once, e.g. to prove they stay separate."
  def put_registries(registries) do
    original = Application.get_env(:athanor, :registries)
    Application.put_env(:athanor, :registries, registries)
    ExUnit.Callbacks.on_exit(fn -> restore(original) end)
    :ok
  end

  defp restore(nil), do: Application.delete_env(:athanor, :registries)
  defp restore(original), do: Application.put_env(:athanor, :registries, original)
end
