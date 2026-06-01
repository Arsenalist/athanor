defmodule Athanor.Test.FakeComponents do
  @moduledoc false

  defmodule Minimal do
    use Athanor.Component

    @impl Athanor.Component
    def metadata, do: %{type: "fake_minimal", label: "Minimal"}
  end

  defmodule Required do
    use Athanor.Component

    @impl Athanor.Component
    def metadata, do: %{type: "fake_required", label: "Required"}

    @impl Athanor.Component
    def required_props, do: ["title", "body"]
  end

  defmodule WithRender do
    use Athanor.Component

    @impl Athanor.Component
    def metadata, do: %{type: "fake_with_render", label: "WithRender"}

    @impl Athanor.Component
    def render(:live, node, _ctx) do
      # Return an iodata-like marker we can grep for in tests.
      Phoenix.HTML.raw("<div data-fake-render=\"#{node["id"]}\"></div>")
    end
  end

  # Legacy-style fake mimicking real Amplify components whose
  # `has_required_props?/1` returns truthy non-booleans (e.g. an integer)
  # via `props["a"] && props["b"]`. Renderer must tolerate this without
  # crashing on `not 6`.
  defmodule LegacyTruthy do
    def has_required_props?(props) do
      props["account_id"] && props["brand_id"]
    end

    def render_public(assigns) do
      Phoenix.HTML.raw(~s(<div data-legacy-truthy="rendered"></div>))
    end
  end
end
