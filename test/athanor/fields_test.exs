defmodule Athanor.FieldsTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  import Phoenix.LiveViewTest

  alias Athanor.Ctx
  alias Athanor.Fields

  # ---------------------------------------------------------------------------
  # Fake components used to exercise each field type
  # ---------------------------------------------------------------------------

  defmodule TextOnly do
    use Athanor.Component
    def metadata, do: %{type: "text_only", label: "T"}
    def fields, do: [{"title", :text, label: "Title", placeholder: "Type..."}]
  end

  defmodule TextareaOnly do
    use Athanor.Component
    def metadata, do: %{type: "textarea_only", label: "T"}
    def fields, do: [{"body", :textarea, label: "Body"}]
  end

  defmodule NumberOnly do
    use Athanor.Component
    def metadata, do: %{type: "number_only", label: "N"}
    def fields, do: [{"count", :number, label: "Count", min: 0, max: 16}]
  end

  defmodule SelectOnly do
    use Athanor.Component
    def metadata, do: %{type: "select_only", label: "S"}

    def fields,
      do: [
        {"level", :select, label: "Level", options: [{"H1", "1"}, {"H2", "2"}, {"H3", "3"}]}
      ]
  end

  defmodule SelectFnOnly do
    use Athanor.Component
    def metadata, do: %{type: "select_fn_only", label: "SF"}

    def fields,
      do: [
        {"venue_id", :select,
         label: "Venue", prompt: "Select a venue", options: &__MODULE__.load_options/1}
      ]

    # Dynamic options receive ctx; close over account_id for the assertion.
    def load_options(ctx) do
      [
        {"Iron Horse (acct: #{ctx.account_id})", "v_1"},
        {"Underground", "v_2"}
      ]
    end
  end

  defmodule RadioOnly do
    use Athanor.Component
    def metadata, do: %{type: "radio_only", label: "R"}

    def fields,
      do: [
        {"level", :radio, label: "Level", options: [{"H1", "1"}, {"H2", "2"}, {"H3", "3"}]}
      ]
  end

  defmodule RadioFnOnly do
    use Athanor.Component
    def metadata, do: %{type: "radio_fn_only", label: "RF"}

    def fields,
      do: [{"venue_id", :radio, label: "Venue", options: &__MODULE__.load_options/1}]

    def load_options(ctx) do
      [
        {"Iron Horse (acct: #{ctx.account_id})", "v_1"},
        {"Underground", "v_2"}
      ]
    end
  end

  defmodule RadioConditional do
    use Athanor.Component
    def metadata, do: %{type: "radio_cond", label: "RC"}

    def fields,
      do: [
        {"align", :radio,
         label: "Align",
         options: [{"Left", "left"}, {"Right", "right"}],
         if: fn props -> props["enabled"] == true end}
      ]
  end

  defmodule ColorOnly do
    use Athanor.Component
    def metadata, do: %{type: "color_only", label: "C"}
    def fields, do: [{"bg", :color, label: "Background"}]
  end

  defmodule CheckboxOnly do
    use Athanor.Component
    def metadata, do: %{type: "checkbox_only", label: "X"}
    def fields, do: [{"enabled", :checkbox, label: "Enabled"}]
  end

  defmodule FakeCustomLC do
    use Phoenix.LiveComponent

    @impl true
    def update(assigns, socket), do: {:ok, Phoenix.Component.assign(socket, assigns)}

    @impl true
    def render(assigns) do
      ~H|<div data-fake-custom-lc data-value={@value} data-label={@label}></div>|
    end
  end

  defmodule CustomOnly do
    use Athanor.Component
    def metadata, do: %{type: "custom_only", label: "K"}
    def fields, do: [{"image", :custom, label: "Image", module: FakeCustomLC}]
  end

  defmodule Mixed do
    use Athanor.Component
    def metadata, do: %{type: "mixed", label: "M"}

    def fields,
      do: [
        {"title", :text, label: "Title"},
        {"image", :custom, label: "Image", module: FakeCustomLC},
        {"variant", :select, label: "Variant", options: [{"A", "a"}, {"B", "b"}]}
      ]
  end

  defmodule NoFields do
    use Athanor.Component
    def metadata, do: %{type: "no_fields", label: "Z"}
  end

  defmodule AssetSingle do
    use Athanor.Component
    def metadata, do: %{type: "asset_single", label: "AS"}
    def fields, do: [{"hero", :asset, label: "Hero", accept: "image/*"}]
  end

  defmodule AssetMultiple do
    use Athanor.Component
    def metadata, do: %{type: "asset_multi", label: "AM"}

    def fields,
      do: [{"gallery", :asset, label: "Gallery", accept: "image/*", multiple: true, max: 12}]
  end

  defmodule AssetConditional do
    use Athanor.Component
    def metadata, do: %{type: "asset_cond", label: "AC"}

    def fields,
      do: [{"hero", :asset, label: "Hero", if: fn props -> props["enabled"] == true end}]
  end

  # ---------------------------------------------------------------------------
  # Test helper
  # ---------------------------------------------------------------------------

  defp render_fields(module, props, opts \\ []) do
    render_fields_ctx(module, props, Ctx.new(), opts)
  end

  defp render_fields_ctx(module, props, ctx, opts \\ []) do
    assigns = %{
      module: module,
      props: props,
      ctx: ctx,
      myself: opts[:myself] || nil,
      on_custom_change: opts[:on_custom_change] || fn _k, _v -> :noop end
    }

    render_component(
      fn assigns ->
        ~H"""
        <Fields.render
          module={@module}
          props={@props}
          ctx={@ctx}
          myself={@myself}
          on_custom_change={@on_custom_change}
        />
        """
      end,
      assigns
    )
  end

  # ---------------------------------------------------------------------------
  # Per-type render tests
  # ---------------------------------------------------------------------------

  describe ":text" do
    test "renders an <input type=text> with name + value + placeholder + label" do
      html = render_fields(TextOnly, %{"title" => "Hi"})
      assert html =~ ~s(<input type="text")
      assert html =~ ~s(name="title")
      assert html =~ ~s(value="Hi")
      assert html =~ ~s(placeholder="Type...")
      assert html =~ "Title"
      assert html =~ ~s(phx-debounce="300")
    end

    test "empty value renders empty string" do
      html = render_fields(TextOnly, %{})
      assert html =~ ~s(value="")
    end
  end

  describe ":textarea" do
    test "renders a <textarea> with name + content + label" do
      html = render_fields(TextareaOnly, %{"body" => "<p>hi</p>"})
      assert html =~ ~s(<textarea name="body")
      assert html =~ "&lt;p&gt;hi&lt;/p&gt;"
      assert html =~ "Body"
    end
  end

  describe ":number" do
    test "renders an <input type=number> with min/max + value" do
      html = render_fields(NumberOnly, %{"count" => 5})
      assert html =~ ~s(<input type="number")
      assert html =~ ~s(name="count")
      assert html =~ ~s(value="5")
      assert html =~ ~s(min="0")
      assert html =~ ~s(max="16")
    end

    test "missing value falls back to 0" do
      html = render_fields(NumberOnly, %{})
      assert html =~ ~s(value="0")
    end
  end

  describe ":select" do
    test "renders a <select> with declared options and selected attr" do
      html = render_fields(SelectOnly, %{"level" => "2"})
      assert html =~ ~s(<select name="level")
      assert html =~ ~s(value="1")
      assert html =~ "H1"
      assert html =~ ~s(<option value="2" selected)
      assert html =~ "H2"
    end

    test "missing value selects no option" do
      html = render_fields(SelectOnly, %{})
      refute html =~ "selected"
    end

    test "integer value matches string option (toString coercion)" do
      html = render_fields(SelectOnly, %{"level" => 3})
      assert html =~ ~s(<option value="3" selected)
    end
  end

  describe ":select with function options (ctx-aware loader)" do
    test "calls the function with ctx and renders the resulting options" do
      ctx = Athanor.Ctx.new(account_id: "acct_abc")
      html = render_fields_ctx(SelectFnOnly, %{"venue_id" => "v_2"}, ctx)

      assert html =~ "Iron Horse (acct: acct_abc)"
      assert html =~ "Underground"
      assert html =~ ~s(<option value="v_2" selected)
    end

    test "prompt renders as first blank option, selected when value missing" do
      ctx = Athanor.Ctx.new(account_id: "acct_abc")
      html = render_fields_ctx(SelectFnOnly, %{}, ctx)

      assert html =~ ~s(<option value="" selected)
      assert html =~ "Select a venue"
    end

    test "prompt rendered but NOT selected when a real value is set" do
      ctx = Athanor.Ctx.new(account_id: "acct_abc")
      html = render_fields_ctx(SelectFnOnly, %{"venue_id" => "v_1"}, ctx)

      # prompt option is present
      assert html =~ "Select a venue"
      # but the value option is the one selected, not the prompt
      assert html =~ ~s(<option value="v_1" selected)
      refute html =~ ~s(<option value="" selected)
    end

    test "exception inside load_options does not crash render" do
      defmodule CrashingFnFake do
        use Athanor.Component
        def metadata, do: %{type: "crash", label: "C"}
        def fields, do: [{"x", :select, label: "X", options: &__MODULE__.boom/1}]
        def boom(_ctx), do: raise("kaboom")
      end

      ctx = Athanor.Ctx.new()
      # Renders an empty select, no crash.
      html = render_fields_ctx(CrashingFnFake, %{}, ctx)
      assert html =~ "<select"
    end
  end

  describe ":radio" do
    test "renders one radio input per option, all sharing the field name" do
      html = render_fields(RadioOnly, %{"level" => "2"})

      assert html =~ ~s(<input type="radio")
      # one input per declared option, all named "level"
      assert length(Regex.scan(~r/<input type="radio"[^>]*name="level"/, html)) == 3
      assert html =~ ~s(value="1")
      assert html =~ ~s(value="2")
      assert html =~ ~s(value="3")
      # labels rendered
      assert html =~ "H1"
      assert html =~ "H2"
      assert html =~ "H3"
    end

    test "marks the matching option checked" do
      html = render_fields(RadioOnly, %{"level" => "2"})

      assert html =~ ~r/<input type="radio"[^>]*value="2"[^>]*checked/
      refute html =~ ~r/<input type="radio"[^>]*value="1"[^>]*checked/
    end

    test "integer value matches string option (toString coercion)" do
      html = render_fields(RadioOnly, %{"level" => 3})
      assert html =~ ~r/<input type="radio"[^>]*value="3"[^>]*checked/
    end

    test "missing/non-matching value checks no option" do
      html = render_fields(RadioOnly, %{})
      refute html =~ "checked"
    end

    test "options as an arity-1 function of ctx resolve at render" do
      ctx = Athanor.Ctx.new(account_id: "acct_abc")
      html = render_fields_ctx(RadioFnOnly, %{"venue_id" => "v_2"}, ctx)

      assert html =~ "Iron Horse (acct: acct_abc)"
      assert html =~ "Underground"
      assert html =~ ~r/<input type="radio"[^>]*value="v_2"[^>]*checked/
    end

    test "renders the label" do
      html = render_fields(RadioOnly, %{})
      assert html =~ "Level"
    end

    test "honors :if conditional — omitted when false, present when true" do
      refute render_fields(RadioConditional, %{"enabled" => false}) =~ ~s(<input type="radio")
      assert render_fields(RadioConditional, %{"enabled" => true}) =~ ~s(<input type="radio")
    end

    test "posts selected value through the fields form (shared name, no custom event)" do
      html = render_fields(RadioOnly, %{"level" => "1"})

      # inputs live inside the single phx-change=update_props form
      assert html =~ ~s(phx-change="update_props")
      assert html =~ ~s(name="level")
      # no field-specific phx-click/phx-target event
      refute html =~ ~r/<input type="radio"[^>]*phx-/
    end
  end

  describe ":color" do
    test "renders an HTML5 color input with #hex value" do
      html = render_fields(ColorOnly, %{"bg" => "#ff0000"})
      assert html =~ ~s(<input type="color")
      assert html =~ ~s(name="bg")
      assert html =~ ~s(value="#ff0000")
    end

    test "missing value falls back to #000000" do
      html = render_fields(ColorOnly, %{})
      assert html =~ ~s(value="#000000")
    end
  end

  describe ":checkbox" do
    test "renders a hidden 'false' input + checkbox, checked when truthy" do
      html = render_fields(CheckboxOnly, %{"enabled" => true})
      assert html =~ ~s(<input type="hidden" name="enabled" value="false")
      assert html =~ ~s(<input type="checkbox" name="enabled" value="true")
      assert html =~ "checked"
    end

    test "unchecked when prop is falsy/missing" do
      html_missing = render_fields(CheckboxOnly, %{})
      html_false = render_fields(CheckboxOnly, %{"enabled" => false})

      refute html_missing =~ ~r/checked(\s|>|"|')/
      refute html_false =~ ~r/checked(\s|>|"|')/
    end
  end

  describe ":custom" do
    test "mounts the consumer's LiveComponent with value/label/ctx assigns" do
      html = render_fields(CustomOnly, %{"image" => "https://x.example/a.jpg"})
      assert html =~ "data-fake-custom-lc"
      assert html =~ ~s(data-value="https://x.example/a.jpg")
      assert html =~ ~s(data-label="Image")
    end

    test "renders even when value is nil" do
      html = render_fields(CustomOnly, %{})
      assert html =~ "data-fake-custom-lc"
    end

    test "passes the full :opts kw to the custom LC so consumer-specific opts (helper, etc.) survive" do
      defmodule OptsConsumerLC do
        use Phoenix.LiveComponent

        @impl true
        def update(assigns, socket), do: {:ok, Phoenix.Component.assign(socket, assigns)}

        @impl true
        def render(assigns) do
          ~H|<div data-helper={@opts[:helper]} data-mode={@opts[:mode]}></div>|
        end
      end

      defmodule WithOpts do
        use Athanor.Component
        def metadata, do: %{type: "with_opts", label: "WO"}

        def fields,
          do: [
            {"x", :custom,
             label: "X", helper: "describe me", mode: "fancy", module: OptsConsumerLC}
          ]
      end

      html = render_fields(WithOpts, %{})
      assert html =~ ~s(data-helper="describe me")
      assert html =~ ~s(data-mode="fancy")
    end
  end

  # ---------------------------------------------------------------------------
  # Layout / structure
  # ---------------------------------------------------------------------------

  describe "form structure" do
    test "wraps built-ins in a single <.form> with phx-change=update_props" do
      html = render_fields(Mixed, %{})

      assert html =~ ~s(phx-change="update_props")
      assert html =~ ~s(data-testid="athanor-fields-form")
    end

    test "custom fields render OUTSIDE the form (separate div)" do
      html = render_fields(Mixed, %{})
      assert html =~ ~s(data-testid="athanor-fields-custom")
    end

    test "no fields → no chrome at all" do
      html = render_fields(NoFields, %{})

      refute html =~ ~s(data-testid="athanor-fields-form")
      refute html =~ ~s(data-testid="athanor-fields-custom")
    end

    test "mixed type schemas preserve declaration order in the form" do
      html = render_fields(Mixed, %{})

      i_title = :binary.match(html, "Title") |> elem(0)
      i_variant = :binary.match(html, "Variant") |> elem(0)

      assert i_title < i_variant
    end
  end

  describe ":if conditional fields" do
    defmodule WithConditional do
      use Athanor.Component
      def metadata, do: %{type: "with_cond", label: "WC"}

      def fields,
        do: [
          {"mode", :select,
           label: "Mode", options: [{"Calendar", "calendar"}, {"Images", "images"}]},
          {"calendar_only", :checkbox,
           label: "Show event list on desktop", if: fn props -> props["mode"] == "calendar" end},
          {"calendar_only_custom", :custom,
           label: "Calendar custom",
           module: FakeCustomLC,
           if: fn props -> props["mode"] == "calendar" end},
          {"always_visible", :checkbox, label: "Always visible"}
        ]
    end

    test "hides field whose :if fn returns false" do
      html = render_fields(WithConditional, %{"mode" => "images"})
      refute html =~ "Show event list on desktop"
      refute html =~ "Calendar custom"
      assert html =~ "Always visible"
    end

    test "shows field whose :if fn returns true" do
      html = render_fields(WithConditional, %{"mode" => "calendar"})
      assert html =~ "Show event list on desktop"
      assert html =~ "Calendar custom"
      assert html =~ "Always visible"
    end

    test "missing :if opt → always visible" do
      html = render_fields(WithConditional, %{})
      assert html =~ "Always visible"
    end

    test ":if fn that raises does not crash render (defaults to visible)" do
      defmodule CrashingIfFake do
        use Athanor.Component
        def metadata, do: %{type: "crash_if", label: "CI"}

        def fields,
          do: [
            {"x", :text, label: "X", if: fn _ -> raise "kaboom" end}
          ]
      end

      html = render_fields(CrashingIfFake, %{})
      assert html =~ "X"
    end
  end

  describe ":asset (single)" do
    test "renders the asset field with a stable testid and no module ref" do
      html = render_fields(AssetSingle, %{})
      assert html =~ ~s(data-testid="athanor-asset-field")
      assert html =~ "Hero"
      refute html =~ "FakeCustomLC"
    end

    test "image descriptor renders a thumbnail from url" do
      html =
        render_fields(AssetSingle, %{
          "hero" => %{
            "url" => "https://x/i.png",
            "name" => "i.png",
            "content_type" => "image/png"
          }
        })

      assert html =~ ~s(data-testid="athanor-asset-preview")
      assert html =~ ~s(<img)
      assert html =~ "https://x/i.png"
    end

    test "non-image descriptor renders the name with no thumbnail" do
      html =
        render_fields(AssetSingle, %{
          "hero" => %{
            "url" => "https://x/d.pdf",
            "name" => "d.pdf",
            "content_type" => "application/pdf"
          }
        })

      assert html =~ "d.pdf"
      refute html =~ ~s(<img)
    end

    test "missing content_type but image extension still renders a thumbnail" do
      html = render_fields(AssetSingle, %{"hero" => %{"url" => "https://x/p.png"}})
      assert html =~ ~s(<img)
      assert html =~ "https://x/p.png"
    end

    test "opaque extra keys are preserved in the rendered URL input value" do
      html =
        render_fields(AssetSingle, %{
          "hero" => %{"url" => "https://x/i.png", "alt" => "logo", "width" => 800}
        })

      # the url drives the text input; extras don't break rendering
      assert html =~ ~s(value="https://x/i.png")
    end

    test "choose control emits athanor_asset_request with key and NO phx-target" do
      html = render_fields(AssetSingle, %{})
      assert html =~ ~s(phx-click="athanor_asset_request")
      assert html =~ ~s(phx-value-key="hero")
      # the choose button must bubble to the LiveView, not the AutoEditorForm LC
      refute html =~ ~r/phx-click="athanor_asset_request"[^>]*phx-target/
    end

    test "renders a URL input named for the field key (paste fallback)" do
      html = render_fields(AssetSingle, %{})
      assert html =~ ~s(name="hero")
    end

    test ":if predicate hides the asset field when false" do
      refute render_fields(AssetConditional, %{"enabled" => false}) =~
               ~s(data-testid="athanor-asset-field")

      assert render_fields(AssetConditional, %{"enabled" => true}) =~
               ~s(data-testid="athanor-asset-field")
    end
  end

  describe ":asset (multiple)" do
    test "empty list renders an add control and zero chips" do
      html = render_fields(AssetMultiple, %{"gallery" => []})
      assert html =~ ~s(data-testid="athanor-asset-add")
      refute html =~ ~s(data-testid="athanor-asset-chip")
    end

    test "renders one chip per descriptor labelled by name + per-item remove" do
      html =
        render_fields(AssetMultiple, %{
          "gallery" => [
            %{"url" => "https://x/a.png", "name" => "a.png", "content_type" => "image/png"},
            %{"url" => "https://x/b.png", "name" => "b.png", "content_type" => "image/png"}
          ]
        })

      chips = html |> String.split(~s(data-testid="athanor-asset-chip")) |> length()
      assert chips - 1 == 2
      assert html =~ "a.png"
      assert html =~ "b.png"
      assert html =~ ~s(data-testid="athanor-asset-remove")
    end

    test "add control emits athanor_asset_request carrying the key" do
      html = render_fields(AssetMultiple, %{"gallery" => []})
      assert html =~ ~s(phx-click="athanor_asset_request")
      assert html =~ ~s(phx-value-key="gallery")
    end
  end

  describe ":asset write-back (statelessness)" do
    test "preview reflects whatever value is passed — no retained state" do
      a = render_fields(AssetSingle, %{"hero" => %{"url" => "https://x/a.png"}})
      b = render_fields(AssetSingle, %{"hero" => %{"url" => "https://x/b.png"}})
      assert a =~ "https://x/a.png"
      refute a =~ "https://x/b.png"
      assert b =~ "https://x/b.png"
      refute b =~ "https://x/a.png"
    end
  end
end
