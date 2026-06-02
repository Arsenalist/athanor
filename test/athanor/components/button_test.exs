defmodule Athanor.Components.ButtonTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Athanor.Components.Button
  alias Athanor.Ctx

  defp render_node(props) do
    rendered =
      Button.render(:live, %{"id" => "b1", "type" => "button", "props" => props}, Ctx.new())

    rendered_to_string(rendered)
  end

  describe "render(:live, ...)" do
    test "emits an anchor with btn classes for default variant + size" do
      html = render_node(%{"label" => "Buy", "href" => "/checkout"})
      assert html =~ ~s(<a)
      assert html =~ ~s(href="/checkout")
      assert html =~ "btn btn-primary btn-md"
      assert html =~ "Buy"
      assert html =~ "</a>"
    end

    test "all variants render correct class" do
      for v <- ["primary", "secondary", "ghost"] do
        html = render_node(%{"label" => "x", "href" => "/", "variant" => v})
        assert html =~ "btn-#{v}", "variant #{v}"
      end
    end

    test "all sizes render correct class" do
      for s <- ["sm", "md", "lg"] do
        html = render_node(%{"label" => "x", "href" => "/", "size" => s})
        assert html =~ "btn-#{s}", "size #{s}"
      end
    end

    test "unknown variant falls back to primary" do
      html = render_node(%{"label" => "x", "href" => "/", "variant" => "neon"})
      assert html =~ "btn-primary"
      refute html =~ "btn-neon"
    end

    test "unknown size falls back to md" do
      html = render_node(%{"label" => "x", "href" => "/", "size" => "huge"})
      assert html =~ "btn-md"
    end

    test "valid targets pass through" do
      for t <- ["_self", "_blank", "_parent", "_top"] do
        html = render_node(%{"label" => "x", "href" => "/", "target" => t})
        assert html =~ ~s(target="#{t}"), "target #{t}"
      end
    end

    test "unknown target falls back to _self" do
      html = render_node(%{"label" => "x", "href" => "/", "target" => "weird"})
      assert html =~ ~s(target="_self")
    end

    test "rel always emitted (default noopener)" do
      html = render_node(%{"label" => "x", "href" => "/"})
      assert html =~ ~s(rel="noopener")
    end

    test "custom rel preserved" do
      html = render_node(%{"label" => "x", "href" => "/", "rel" => "nofollow noopener"})
      assert html =~ ~s(rel="nofollow noopener")
    end
  end

  describe "behaviour metadata" do
    test "required_props" do
      assert Button.required_props() == ["label", "href"]
    end

    test "fields/0 declares label/href/variant/size/target/rel" do
      fields = Button.fields()
      keys = Enum.map(fields, fn {k, _t, _o} -> k end)
      assert keys == ["label", "href", "variant", "size", "target", "rel"]

      assert {"variant", :select, opts} = Enum.find(fields, &match?({"variant", _, _}, &1))
      assert length(opts[:options]) == 3
    end

    test "editor_form/0 returns nil (legacy callback no longer overridden)" do
      assert Button.editor_form() == nil
    end

    test "metadata type/label" do
      meta = Button.metadata()
      assert meta.type == "button"
      assert meta.label == "Button"
    end
  end
end
