defmodule Athanor.ComponentFieldsTest do
  use ExUnit.Case, async: true

  defmodule MinimalNoFields do
    use Athanor.Component
    def metadata, do: %{type: "min_no_fields", label: "MNF"}
  end

  defmodule WithFields do
    use Athanor.Component
    def metadata, do: %{type: "with_fields", label: "WF"}

    def fields,
      do: [
        {"title", :text, label: "Title"},
        {"level", :select, label: "Level", options: [{"H1", "1"}, {"H2", "2"}]}
      ]
  end

  describe "fields/0 callback default" do
    test "components that don't override get an empty list" do
      assert MinimalNoFields.fields() == []
    end
  end

  describe "fields/0 override" do
    test "components can override and return their schema" do
      fields = WithFields.fields()
      assert length(fields) == 2

      assert {"title", :text, opts} = Enum.at(fields, 0)
      assert opts[:label] == "Title"

      assert {"level", :select, opts2} = Enum.at(fields, 1)
      assert opts2[:label] == "Level"
      assert opts2[:options] == [{"H1", "1"}, {"H2", "2"}]
    end
  end

  describe "function_exported? detection (used by Renderer dispatch)" do
    test "Code.ensure_loaded! + function_exported? returns true after use" do
      Code.ensure_loaded!(WithFields)
      assert function_exported?(WithFields, :fields, 0)
    end

    test "still true for components that don't override (because of injected default)" do
      Code.ensure_loaded!(MinimalNoFields)
      assert function_exported?(MinimalNoFields, :fields, 0)
      # Empty list is the "no fields declared" signal.
      assert MinimalNoFields.fields() == []
    end
  end
end
