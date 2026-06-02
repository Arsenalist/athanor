defmodule Athanor.FieldTest do
  use ExUnit.Case, async: true

  defmodule MinimalField do
    use Phoenix.LiveComponent

    @impl true
    def update(assigns, socket), do: {:ok, Phoenix.Component.assign(socket, assigns)}

    @impl true
    def render(assigns) do
      ~H|<div data-fake-field-value={@value}></div>|
    end
  end

  defmodule NotAField do
    def hello, do: :world
  end

  describe "implements?/1" do
    test "returns true for a LiveComponent matching the contract" do
      assert Athanor.Field.implements?(MinimalField)
    end

    test "returns false for a non-LiveComponent module" do
      refute Athanor.Field.implements?(NotAField)
    end

    test "returns false for a non-loaded / nonexistent module" do
      refute Athanor.Field.implements?(:non_existent_module_xyz)
    end
  end
end
