defmodule Athanor.RegistryTest do
  # Async false because tests mutate :athanor application env.
  use ExUnit.Case, async: false

  import Athanor.Test.RegistryHelpers

  alias Athanor.Registry
  alias Athanor.Test.FakeComponents.{Minimal, Required, WithRender}

  describe "lookup/2" do
    test "returns the registered module by type" do
      put_test_registry([Minimal, Required])

      assert Registry.lookup(:test, "fake_minimal") == Minimal
      assert Registry.lookup(:test, "fake_required") == Required
    end

    test "returns nil when type unknown and no fallback configured" do
      put_test_registry([Minimal])

      assert Registry.lookup(:test, "does_not_exist") == nil
    end

    test "calls the registry's fallback resolver when the type is unknown" do
      defmodule FallbackHit do
        def resolve("matched_by_fallback"), do: WithRender
        def resolve(_), do: nil
      end

      put_test_registry([], fallback_resolver: {FallbackHit, :resolve})

      assert Registry.lookup(:test, "matched_by_fallback") == WithRender
      assert Registry.lookup(:test, "ignored_by_fallback") == nil
    end

    test "registered components take precedence over fallback" do
      defmodule ShouldNotBeCalled do
        def resolve(_), do: raise("fallback called when it shouldn't be")
      end

      put_test_registry([Minimal], fallback_resolver: {ShouldNotBeCalled, :resolve})

      assert Registry.lookup(:test, "fake_minimal") == Minimal
    end
  end

  describe "registry scoping" do
    setup do
      put_registries(
        page_builder: [components: [Minimal]],
        channel_overlays: [components: [Required]]
      )
    end

    test "a type registered in one registry does not resolve in another" do
      assert Registry.lookup(:page_builder, "fake_minimal") == Minimal
      assert Registry.lookup(:channel_overlays, "fake_minimal") == nil

      assert Registry.lookup(:channel_overlays, "fake_required") == Required
      assert Registry.lookup(:page_builder, "fake_required") == nil
    end

    test "each palette lists only its own components" do
      assert Registry.all(:page_builder) == [Minimal]
      assert Registry.all(:channel_overlays) == [Required]

      assert Registry.components_metadata(:page_builder) |> Enum.map(& &1.type) ==
               ["fake_minimal"]
    end

    test "a fallback resolver belongs to its registry alone" do
      defmodule ScopedFallback do
        def resolve(_type), do: WithRender
      end

      put_registries(
        page_builder: [components: [], fallback_resolver: {ScopedFallback, :resolve}],
        channel_overlays: [components: []]
      )

      assert Registry.lookup(:page_builder, "anything") == WithRender
      assert Registry.lookup(:channel_overlays, "anything") == nil
    end

    test "registries/0 names what is configured" do
      assert Enum.sort(Registry.registries()) == [:channel_overlays, :page_builder]
    end
  end

  describe "metadata_for/2" do
    test "returns the resolved module's metadata for a registered type" do
      put_test_registry([Minimal])

      meta = Registry.metadata_for(:test, "fake_minimal")
      assert meta.type == "fake_minimal"
      assert meta.label == "Minimal"
    end

    test "returns nil for unknown type with no fallback" do
      put_test_registry([])

      assert Registry.metadata_for(:test, "ghost") == nil
    end
  end

  describe "components_metadata/1" do
    test "returns metadata for each registered module" do
      put_test_registry([Minimal, Required])

      types = Registry.components_metadata(:test) |> Enum.map(& &1.type)

      assert "fake_minimal" in types
      assert "fake_required" in types
    end

    test "no duplicate types in a normal registration" do
      put_test_registry([Minimal, Required])

      types = Registry.components_metadata(:test) |> Enum.map(& &1.type)
      assert types == Enum.uniq(types)
    end

    test "detects duplicates when present (programmer error)" do
      # If two components ever claim the same type, lookup returns the
      # first silently. The audit should catch it.
      put_test_registry([Minimal, Minimal])

      types = Registry.components_metadata(:test) |> Enum.map(& &1.type)
      duplicates = types -- Enum.uniq(types)

      refute duplicates == [], "audit should detect duplicates when registry has them"
    end
  end

  describe "all/1" do
    test "returns the configured component module list" do
      put_test_registry([Minimal, Required, WithRender])

      assert Registry.all(:test) == [Minimal, Required, WithRender]
    end

    test "returns [] for a registry configured with no components" do
      put_test_registry([])
      assert Registry.all(:test) == []
    end
  end

  describe "configuration errors are loud" do
    test "an unknown registry names the ones that exist" do
      put_registries(page_builder: [components: [Minimal]])

      assert_raise ArgumentError, ~r/unknown Athanor registry :typo.*page_builder/s, fn ->
        Registry.lookup(:typo, "fake_minimal")
      end
    end

    test "no registry at all is a clear error, not an empty palette" do
      put_registries(page_builder: [components: [Minimal]])

      assert_raise ArgumentError, ~r/no Athanor registry given/, fn ->
        Registry.lookup(nil, "fake_minimal")
      end
    end

    test "a non-atom registry is rejected" do
      put_registries(page_builder: [components: []])

      assert_raise ArgumentError, ~r/must be an atom/, fn ->
        Registry.lookup("page_builder", "fake_minimal")
      end
    end

    test "a registry configured with something other than a keyword list is rejected" do
      put_registries(page_builder: %{components: [Minimal]})

      assert_raise ArgumentError, ~r/must be configured as a keyword list/, fn ->
        Registry.all(:page_builder)
      end
    end

    test "the pre-registries flat config is refused with migration instructions" do
      put_registries(page_builder: [components: [Minimal]])
      Application.put_env(:athanor, :components, [Minimal])
      on_exit(fn -> Application.delete_env(:athanor, :components) end)

      assert_raise ArgumentError, ~r/no longer supported.*registries are named/s, fn ->
        Registry.lookup(:page_builder, "fake_minimal")
      end
    end

    test "a stray flat :fallback_resolver is refused too" do
      put_registries(page_builder: [components: [Minimal]])
      Application.put_env(:athanor, :fallback_resolver, {SomeMod, :resolve})
      on_exit(fn -> Application.delete_env(:athanor, :fallback_resolver) end)

      assert_raise ArgumentError, ~r/no longer supported/, fn ->
        Registry.all(:page_builder)
      end
    end
  end
end
