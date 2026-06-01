defmodule Athanor.FixtureHelpers do
  @moduledoc false

  @fixtures_dir Path.join([__DIR__, "fixtures", "athanor_tree"])

  @doc """
  Load a fixture JSON file from `test/support/fixtures/athanor_tree/<name>.json`
  and return it as a decoded Elixir map.
  """
  def load_fixture(name) do
    @fixtures_dir
    |> Path.join("#{name}.json")
    |> File.read!()
    |> JSON.decode!()
  end

  @doc """
  Return the absolute paths of every fixture file in
  `test/support/fixtures/athanor_tree/`.
  """
  def all_fixture_paths do
    @fixtures_dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
