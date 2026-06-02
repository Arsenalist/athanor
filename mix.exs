defmodule Athanor.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Arsenalist/athanor"

  @moduledoc false

  # Athanor — host-agnostic page builder library for Phoenix LiveView apps.
  #
  # The boundary is physical: nothing here may reference `Amplify.*`,
  # `AmplifyWeb.*`, `Ecto.*`, or gettext. Phoenix LiveView is fair game —
  # it's a framework primitive, not host-app coupling. The architecture
  # test in `test/athanor/tree_architecture_test.exs` enforces this.
  #
  # JSON encoding is the caller's responsibility — Athanor accepts and
  # returns already-decoded maps.

  def project do
    [
      app: :athanor,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Athanor",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix LiveView for `Phoenix.Component`, ~H sigil, and
      # `Phoenix.LiveComponent` used throughout the editor and field
      # subsystems. Brings :phoenix, :phoenix_html, :phoenix_template
      # transitively — framework primitives, not host-app coupling.
      {:phoenix_live_view, "~> 1.1"},

      # Documentation generation. Dev-only.
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},

      # Required by `Phoenix.LiveView.JS` for serialising click commands.
      # Consumer apps almost always pull this in transitively; here it's
      # pinned so the library's own test suite can exercise JS commands.
      {:jason, "~> 1.4", only: [:test]}
    ]
  end

  defp description do
    "Host-agnostic page builder library for Phoenix LiveView apps. " <>
      "Turn-key drag-edit editor mounted via a use macro; components are plain Elixir modules."
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Zarar Siddiqi"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Hexdocs" => "https://hexdocs.pm/athanor"
      },
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md CONTRIBUTING.md CODE_OF_CONDUCT.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md": [title: "Contributing"],
        "CODE_OF_CONDUCT.md": [title: "Code of Conduct"],
        LICENSE: [title: "License"]
      ],
      groups_for_modules: [
        Core: [
          Athanor.Tree,
          Athanor.Component,
          Athanor.Registry,
          Athanor.Renderer,
          Athanor.Ctx
        ],
        Editor: [
          Athanor.Editor,
          Athanor.Editor.Live,
          Athanor.Editor.State
        ],
        Fields: [
          Athanor.Fields,
          Athanor.Field,
          Athanor.AutoEditorForm,
          Athanor.Components.EditorFormShell,
          Athanor.Components.Formatting,
          Athanor.Components.Formatting.EditorForm
        ],
        "Built-in Components": [
          Athanor.Components.Button,
          Athanor.Components.Columns,
          Athanor.Components.Divider,
          Athanor.Components.Heading,
          Athanor.Components.Text
        ]
      ]
    ]
  end
end
