defmodule Athanor.MixProject do
  use Mix.Project

  @moduledoc false

  # Athanor — host-agnostic page builder + (later) email builder library.
  #
  # This is a path-dependency mix project (the parent app adds
  # `{:athanor, path: "athanor"}`). The boundary is physical: nothing here may
  # reference `Amplify.*`, `AmplifyWeb.*`, `Phoenix.*`, `Ecto.*`, or gettext.
  # Future steps may add `:phoenix_live_view` and `:phoenix_html` when the
  # editor LiveView and renderer land, but those are additive — Amplify and
  # Ecto remain out forever.
  #
  # JSON encoding is the caller's responsibility — Athanor accepts and
  # returns already-decoded maps.

  def project do
    [
      app: :athanor,
      version: "0.0.1",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix LiveView for `Phoenix.Component`, ~H sigil, and (later)
      # `Phoenix.LiveComponent` in `Athanor.Editor.Live`. Brings :phoenix,
      # :phoenix_html, :phoenix_template transitively — fine, they are
      # framework primitives, not host-app coupling.
      {:phoenix_live_view, "~> 1.1"},
      # Required by `Phoenix.LiveView.JS` for serialising click commands.
      # Consumer apps almost always already pull this in; here it's pinned
      # so the library's own test suite can exercise JS commands.
      {:jason, "~> 1.4", only: [:test]}
    ]
  end
end
