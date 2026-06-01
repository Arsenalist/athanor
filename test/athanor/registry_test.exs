defmodule Athanor.RegistryTest do
  # Async false because tests mutate :athanor application env.
  use ExUnit.Case, async: false

  alias Athanor.Registry
  alias Athanor.Test.FakeComponents.{Minimal, Required, WithRender}

  setup do
    original_components = Application.get_env(:athanor, :components)
    original_fallback = Application.get_env(:athanor, :fallback_resolver)

    on_exit(fn ->
      reset(:components, original_components)
      reset(:fallback_resolver, original_fallback)
    end)

    :ok
  end

  defp reset(key, nil), do: Application.delete_env(:athanor, key)
  defp reset(key, value), do: Application.put_env(:athanor, key, value)

  defp set_components(modules) do
    Application.put_env(:athanor, :components, modules)
  end

  defp set_fallback(mod_fun), do: Application.put_env(:athanor, :fallback_resolver, mod_fun)
  defp clear_fallback, do: Application.delete_env(:athanor, :fallback_resolver)

  describe "lookup/1" do
    test "returns the registered module by type" do
      set_components([Minimal, Required])

      assert Registry.lookup("fake_minimal") == Minimal
      assert Registry.lookup("fake_required") == Required
    end

    test "returns nil when type unknown and no fallback configured" do
      set_components([Minimal])
      clear_fallback()

      assert Registry.lookup("does_not_exist") == nil
    end

    test "calls fallback resolver when type unknown and fallback configured" do
      set_components([])

      defmodule FallbackHit do
        def resolve("matched_by_fallback"), do: WithRender
        def resolve(_), do: nil
      end

      set_fallback({FallbackHit, :resolve})

      assert Registry.lookup("matched_by_fallback") == WithRender
      assert Registry.lookup("ignored_by_fallback") == nil
    end

    test "registered components take precedence over fallback" do
      set_components([Minimal])

      defmodule ShouldNotBeCalled do
        def resolve(_), do: raise("fallback called when it shouldn't be")
      end

      set_fallback({ShouldNotBeCalled, :resolve})

      assert Registry.lookup("fake_minimal") == Minimal
    end
  end

  describe "metadata_for/1" do
    test "returns the resolved module's metadata for a registered type" do
      set_components([Minimal])

      meta = Registry.metadata_for("fake_minimal")
      assert meta.type == "fake_minimal"
      assert meta.label == "Minimal"
    end

    test "returns nil for unknown type with no fallback" do
      set_components([])
      clear_fallback()

      assert Registry.metadata_for("ghost") == nil
    end
  end

  describe "components_metadata/0" do
    test "returns metadata for each registered module" do
      set_components([Minimal, Required])

      metas = Registry.components_metadata()
      types = Enum.map(metas, & &1.type)

      assert "fake_minimal" in types
      assert "fake_required" in types
    end

    test "no duplicate types in a normal registration" do
      set_components([Minimal, Required])

      types = Registry.components_metadata() |> Enum.map(& &1.type)
      assert types == Enum.uniq(types)
    end

    test "detects duplicates when present (programmer error)" do
      # If two components ever claim the same type, lookup returns the
      # first silently. The audit should catch it.
      set_components([Minimal, Minimal])

      types = Registry.components_metadata() |> Enum.map(& &1.type)
      duplicates = types -- Enum.uniq(types)

      refute duplicates == [], "audit should detect duplicates when registry has them"
    end
  end

  describe "all/0" do
    test "returns the configured component module list" do
      set_components([Minimal, Required, WithRender])

      assert Registry.all() == [Minimal, Required, WithRender]
    end

    test "returns [] when nothing configured" do
      Application.delete_env(:athanor, :components)
      assert Registry.all() == []
    end
  end
end
