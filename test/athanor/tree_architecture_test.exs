defmodule Athanor.TreeArchitectureTest do
  use ExUnit.Case, async: true

  @tree_source Path.expand("../../lib/athanor/tree.ex", __DIR__)

  # Files allowed to reference AmplifyWeb modules. The Text component is a
  # documented exception: it bridges editing to the legacy
  # AmplifyWeb.PageBuilder.Components.Text LC via `editor_form/0` until the
  # rich-text + asset adapters land (Step 5). See the component's @moduledoc.
  @amplify_web_exceptions [
    Path.expand("../../lib/athanor/components/text.ex", __DIR__)
  ]

  @forbidden_aliases [
    "alias Amplify",
    "alias AmplifyWeb",
    "alias Phoenix",
    "alias Ecto",
    "alias Jason",
    "import Amplify",
    "import AmplifyWeb",
    "Jason.",
    "JSON.encode",
    "JSON.decode"
  ]

  describe "mix.exs deps boundary" do
    # The hard rule: no host-app coupling, no DB, no JSON encoding lib.
    # Phoenix LiveView (and its transitive :phoenix, :phoenix_html, etc.) is
    # allowed because Athanor.Renderer is a function component that uses the
    # ~H sigil. Phoenix as a framework is fine; Amplify as an app is not.
    test "Athanor.MixProject declares zero forbidden runtime dependencies" do
      deps = Athanor.MixProject.project()[:deps] || []

      # Allow test-only deps (only: [:test] tuple opt) since they don't
      # affect runtime. Currently jason is included as test-only so the
      # suite can exercise Phoenix.LiveView.JS.* serialisation.
      runtime_deps =
        deps
        |> Enum.reject(fn dep -> test_only?(dep) end)
        |> Enum.map(&elem(&1, 0))

      forbidden = [:amplify, :ecto_sql, :jason]
      offenders = Enum.filter(runtime_deps, &(&1 in forbidden))

      assert offenders == [],
             "athanor/mix.exs must not depend on: #{inspect(offenders)} at runtime.\n" <>
               "Athanor is host-agnostic — no Amplify, Ecto, Jason runtime deps allowed."
    end

    defp test_only?({_name, _ver, opts}) when is_list(opts),
      do: Keyword.get(opts, :only) in [:test, [:test]]

    defp test_only?({_name, opts}) when is_list(opts),
      do: Keyword.get(opts, :only) in [:test, [:test]]

    defp test_only?(_), do: false
  end

  describe "tree.ex source boundary (belt-and-suspenders)" do
    test "lib/athanor/tree.ex contains no forbidden aliases or JSON calls" do
      source = File.read!(@tree_source)

      for needle <- @forbidden_aliases do
        refute String.contains?(source, needle),
               "lib/athanor/tree.ex must not contain `#{needle}`.\n" <>
                 "Athanor.Tree is pure-data; encoding is the caller's responsibility."
      end
    end
  end

  describe "Athanor library AmplifyWeb boundary" do
    test "no lib/athanor/**/*.ex file references AmplifyWeb except documented exceptions" do
      lib_root = Path.expand("../../lib/athanor", __DIR__)

      offenders =
        Path.wildcard(Path.join(lib_root, "**/*.ex"))
        |> Enum.reject(&(&1 in @amplify_web_exceptions))
        |> Enum.filter(fn path ->
          source = File.read!(path)
          String.contains?(source, "AmplifyWeb")
        end)

      assert offenders == [],
             "These Athanor lib files reference AmplifyWeb without being in the\n" <>
               "documented exception list — add to @amplify_web_exceptions only when there is\n" <>
               "no other way:\n" <>
               Enum.map_join(offenders, "\n", &"  - #{Path.relative_to(&1, File.cwd!())}")
    end
  end

  describe "documentation coverage" do
    test "every public function in Athanor.Tree has a @doc string" do
      {:docs_v1, _anno, _lang, _format, _module_doc, _meta, function_docs} =
        Code.fetch_docs(Athanor.Tree)

      undocumented =
        function_docs
        |> Enum.filter(fn {{kind, _name, _arity}, _, _, _, _meta} -> kind == :function end)
        |> Enum.reject(fn {_id, _anno, _sig, doc, _meta} ->
          case doc do
            %{"en" => str} when is_binary(str) and str != "" -> true
            _ -> false
          end
        end)
        |> Enum.map(fn {{_kind, name, arity}, _, _, _, _} -> "#{name}/#{arity}" end)

      assert undocumented == [],
             "Public functions without @doc: #{Enum.join(undocumented, ", ")}"
    end
  end
end
