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

    def render_public(_assigns) do
      Phoenix.HTML.raw(~s(<div data-legacy-truthy="rendered"></div>))
    end
  end

  # Used by renderer_editor_form_test.exs to exercise the editor-form
  # dispatch path. Implements both render/3 (preview/storefront) and
  # editor_form/0 (config panel).
  defmodule EditorFormFakeLC do
    use Phoenix.LiveComponent

    @impl true
    def render(assigns) do
      ~H"""
      <div data-editor-form-fake-lc={@component_id}>edit panel</div>
      """
    end
  end

  defmodule EditorFormFake do
    use Athanor.Component

    @impl Athanor.Component
    def metadata, do: %{type: "fake_editor_form", label: "EditorFormFake"}

    @impl Athanor.Component
    def render(:live, node, _ctx) do
      Phoenix.HTML.raw(~s(<div data-preview="#{node["id"]}">preview</div>))
    end

    @impl Athanor.Component
    def editor_form, do: EditorFormFakeLC
  end

  defmodule NoEditorFormFake do
    use Athanor.Component

    @impl Athanor.Component
    def metadata, do: %{type: "fake_no_editor_form", label: "NoEditorFormFake"}

    @impl Athanor.Component
    def render(:live, node, _ctx) do
      Phoenix.HTML.raw(~s(<div data-no-form="#{node["id"]}">no form</div>))
    end

    # editor_form/0 explicitly returns nil → renderer should fall through to render/3.
    @impl Athanor.Component
    def editor_form, do: nil
  end
end
