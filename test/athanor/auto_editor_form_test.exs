defmodule Athanor.AutoEditorFormTest do
  use ExUnit.Case, async: true

  alias Athanor.AutoEditorForm
  alias Athanor.Ctx

  defmodule FakeComponent do
    use Athanor.Component
    def metadata, do: %{type: "fake_ae", label: "Fake"}

    def fields,
      do: [
        {"title", :text, label: "Title"},
        {"count", :number, label: "Count"},
        {"enabled", :checkbox, label: "Enabled"},
        {"level", :select, label: "Level", options: [{"H1", "1"}, {"H2", "2"}]}
      ]
  end

  # Build a minimal LiveComponent socket-like struct via direct field access.
  defp build_socket(assigns) do
    %Phoenix.LiveView.Socket{
      assigns: Map.put_new(assigns, :__changed__, %{}),
      private: %{},
      transport_pid: nil
    }
  end

  describe "update/2 — initial mount" do
    test "fills active_tab + open_sections + formatting_form defaults" do
      socket = build_socket(%{})

      {:ok, new_socket} =
        AutoEditorForm.update(
          %{
            id: "ae-1",
            component_id: "node-1",
            component_module: FakeComponent,
            props: %{},
            ctx: Ctx.new()
          },
          socket
        )

      assert new_socket.assigns.active_tab == "component"
      assert MapSet.member?(new_socket.assigns.open_sections, "colors")
      assert new_socket.assigns.formatting_form
      assert new_socket.assigns.component_module == FakeComponent
      assert new_socket.assigns.props == %{}
    end

    test "preserves existing active_tab / open_sections via assign_new" do
      socket = build_socket(%{active_tab: "formatting", open_sections: MapSet.new(["padding"])})

      {:ok, new_socket} =
        AutoEditorForm.update(
          %{
            id: "ae-2",
            component_id: "node-2",
            component_module: FakeComponent,
            props: %{},
            ctx: Ctx.new()
          },
          socket
        )

      assert new_socket.assigns.active_tab == "formatting"
      assert MapSet.member?(new_socket.assigns.open_sections, "padding")
    end
  end

  describe "handle_event(\"switch_tab\")" do
    test "updates active_tab" do
      socket = build_socket(%{active_tab: "component"})

      {:noreply, new_socket} =
        AutoEditorForm.handle_event("switch_tab", %{"tab" => "formatting"}, socket)

      assert new_socket.assigns.active_tab == "formatting"
    end
  end

  describe "handle_event(\"toggle_section\")" do
    test "adds when missing, removes when present" do
      socket = build_socket(%{open_sections: MapSet.new(["colors"])})

      {:noreply, s1} =
        AutoEditorForm.handle_event("toggle_section", %{"section" => "padding"}, socket)

      assert MapSet.member?(s1.assigns.open_sections, "padding")

      {:noreply, s2} =
        AutoEditorForm.handle_event("toggle_section", %{"section" => "padding"}, s1)

      refute MapSet.member?(s2.assigns.open_sections, "padding")
    end
  end

  describe "handle_event(\"update_props\") — component fields" do
    test "merges flat params into props with type coercion" do
      socket =
        build_socket(%{
          component_module: FakeComponent,
          component_id: "node-1",
          props: %{"title" => "old"}
        })

      params = %{
        "title" => "new",
        "count" => "12",
        "enabled" => "true",
        "level" => "2",
        # csrf / non-field garbage is ignored
        "_csrf_token" => "abc"
      }

      {:noreply, _} = AutoEditorForm.handle_event("update_props", params, socket)

      assert_received {:update_component_props, "node-1", new_props}
      assert new_props["title"] == "new"
      assert new_props["count"] == 12
      assert new_props["enabled"] == true
      assert new_props["level"] == "2"
      refute Map.has_key?(new_props, "_csrf_token")
    end

    test "checkbox unchecked = \"false\" coerces to false" do
      socket =
        build_socket(%{
          component_module: FakeComponent,
          component_id: "n1",
          props: %{"enabled" => true}
        })

      {:noreply, _} =
        AutoEditorForm.handle_event(
          "update_props",
          %{"enabled" => "false"},
          socket
        )

      assert_received {:update_component_props, "n1", new_props}
      assert new_props["enabled"] == false
    end
  end

  describe "handle_event(\"update_props\") — formatting tab" do
    test "merges formatting params under props[\"formatting\"] wholesale" do
      socket =
        build_socket(%{
          component_module: FakeComponent,
          component_id: "n2",
          props: %{"title" => "x", "formatting" => %{"text_color" => "#000"}}
        })

      params = %{
        "formatting" => %{
          "alignment" => "center",
          "padding_top" => "16",
          "text_color" => "#ff0000",
          "background_color" => "",
          "border_color" => "",
          "padding_bottom" => "0",
          "padding_left" => "0",
          "padding_right" => "0",
          "margin_top" => "0",
          "margin_bottom" => "0",
          "margin_left" => "0",
          "margin_right" => "0",
          "border_radius" => "0",
          "border_width" => "0"
        }
      }

      {:noreply, _} = AutoEditorForm.handle_event("update_props", params, socket)

      assert_received {:update_component_props, "n2", new_props}
      assert new_props["title"] == "x"
      assert new_props["formatting"]["alignment"] == "center"
      assert new_props["formatting"]["padding_top"] == 16
      assert new_props["formatting"]["text_color"] == "#ff0000"
    end
  end

  describe "update/2 — custom field on_change action" do
    test "stores the value and notifies parent" do
      socket =
        build_socket(%{
          component_module: FakeComponent,
          component_id: "n3",
          props: %{}
        })

      {:ok, new_socket} =
        AutoEditorForm.update(
          %{action: {:custom_field_changed, "image", "https://x/y.jpg"}},
          socket
        )

      assert new_socket.assigns.props == %{"image" => "https://x/y.jpg"}
      assert_received {:update_component_props, "n3", %{"image" => "https://x/y.jpg"}}
    end
  end

  describe "coerce/2" do
    test "number from string → integer" do
      assert AutoEditorForm.coerce("16", :number) == 16
    end

    test "number from non-numeric → 0" do
      assert AutoEditorForm.coerce("abc", :number) == 0
    end

    test "checkbox 'true'/'false' → booleans" do
      assert AutoEditorForm.coerce("true", :checkbox) == true
      assert AutoEditorForm.coerce("false", :checkbox) == false
    end

    test "other types pass through unchanged" do
      assert AutoEditorForm.coerce("hello", :text) == "hello"
      assert AutoEditorForm.coerce("2", :select) == "2"
      assert AutoEditorForm.coerce("#ff0000", :color) == "#ff0000"
    end
  end
end
