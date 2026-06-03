# Athanor

[![Hex.pm](https://img.shields.io/hexpm/v/athanor.svg)](https://hex.pm/packages/athanor)
[![Hexdocs.pm](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/athanor)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Host-agnostic page builder library for Phoenix LiveView apps.

Athanor gives you a turn-key drag-edit page editor — canvas, components
panel, configure panel, viewport switcher, formatting tab — that you
mount inside your own LiveView with a `use` macro. You declare your
components as plain Elixir modules and Athanor handles the rest:
serialization, render dispatch, form generation, edit chrome.

It is **not** an admin CMS. It does not ship a database, an HTTP
endpoint, or an opinion about where pages get stored. It hands you a
content tree (`%{"content" => [%{"id" => _, "type" => _, "props" => _}, ...]}`)
and trusts your app to load/save it.

Inspired by [Puck.js](https://puckeditor.com/) (React) — Athanor brings
its `resolveFields`/`resolveData` mental model to the BEAM.

> **Status:** early — `0.x`. Public API may shift between minor
> versions. See [CHANGELOG.md](CHANGELOG.md) for what changed.
> Production-used by [Amplify](https://amplify.events).

## Install

```elixir
def deps do
  [
    {:athanor, "~> 0.1"}
  ]
end
```

If you use Tailwind v4, point `@source` at Athanor so utility classes
in the editor chrome get scanned:

```css
/* assets/css/app.css */
@source "../../deps/athanor/lib/**/*.*ex";
```

## 60-second tour

### 1. Declare a component

```elixir
defmodule MyApp.Components.Hero do
  use Athanor.Component
  use Phoenix.Component

  @impl Athanor.Component
  def metadata, do: %{type: "hero", label: "Hero", icon: "fa-image"}

  @impl Athanor.Component
  def fields do
    [
      {"title", :text, label: "Title"},
      {"subtitle", :textarea, label: "Subtitle"}
    ]
  end

  @impl Athanor.Component
  def render(:live, node, _ctx) do
    assigns = node["props"]
    ~H"""
    <section class="py-24 text-center">
      <h1 class="text-5xl font-bold">{@title}</h1>
      <p class="mt-4 text-lg">{@subtitle}</p>
    </section>
    """
  end
end
```

### 2. Register it

```elixir
# config/config.exs
config :athanor, components: [MyApp.Components.Hero]
```

### 3. Mount the editor

Pages store one field — `editor_content` — that is the whole tree
(`%{"content" => [...]}`). Editor and storefront both read/write the
same map.

```elixir
defmodule MyAppWeb.PageEditorLive do
  use Athanor.Editor.Live

  @impl Athanor.Editor
  def load(%{"id" => id}, _session, _socket) do
    page = MyApp.Pages.get_page!(id)

    {:ok,
     %{
       content: page.editor_content || %{"content" => []},
       metadata: %{},
       ctx_assigns: %{}
     }}
  end

  @impl Athanor.Editor
  def save(socket, %{content: content}) do
    MyApp.Pages.update_page(socket.assigns.page, %{editor_content: content})
  end
end
```

Wire the route:

```elixir
live "/admin/pages/:id/edit", MyAppWeb.PageEditorLive
```

### 4. Render the saved page on the storefront

Same `editor_content` map, no editor chrome — `Athanor.Renderer.tree/1`
dispatches each node to its component's `render/3`.

```elixir
defmodule MyAppWeb.PageLive do
  use MyAppWeb, :live_view

  def mount(%{"slug" => slug}, _session, socket) do
    page = MyApp.Pages.get_page_by_slug!(slug)
    {:ok, assign(socket, :page, page)}
  end

  def render(assigns) do
    ~H"""
    <Athanor.Renderer.tree
      tree={@page.editor_content}
      ctx={Athanor.Ctx.new()}
      edit_mode={false}
    />
    """
  end
end
```

That's the whole integration. The editor canvas, components palette,
auto-generated config forms (one input per `fields/0` entry), the
formatting tab (alignment / colors / padding / margin / borders), a
viewport switcher, and a Save button all come from `use
Athanor.Editor.Live`. Your storefront renders the same tree without
any of that chrome.

### 5. Wire the drag-and-drop hooks (optional but recommended)

The editor supports drag-and-drop out of the box: drag from the
components palette onto the canvas, reorder canvas items by dragging
them up or down, drag children in and out of `Columns` zones. The
server-side handler is built in; you only need to register the two
JS hooks that ship with the library:

```js
// assets/js/app.js
import { AthanorHooks } from "athanor"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...AthanorHooks /* your other hooks */ }
})
```

Hooks use native HTML5 DnD — no JS dependency.

## Concepts

| Module | Role |
|---|---|
| `Athanor.Tree` | Pure-data manipulation of the content tree (`insert`, `move`, `remove`, `find`) |
| `Athanor.Component` | Behaviour + `use` macro for declaring components |
| `Athanor.Registry` | Runtime lookup of components by `"type"` string |
| `Athanor.Renderer` | Dispatches each node to its component's `render/3` |
| `Athanor.Ctx` | Render/edit context (`account_id`, `brand_id`, `edit_mode?`, etc.) |
| `Athanor.Editor.Live` | `use` macro that injects the LiveView |
| `Athanor.Editor` | Function components (`canvas`, `components_panel`, `config_panel`, `shell`) for custom layouts |
| `Athanor.Fields` | Auto-renders a component's `fields/0` schema into form inputs |
| `Athanor.Field` | Behaviour-style contract for custom field LiveComponents |
| `Athanor.AutoEditorForm` | LiveComponent wrapping the auto-form plumbing |

### Field types

`fields/0` returns a list of `{key, type, opts}` tuples. Built-in types:

- `:text` — text input
- `:textarea` — textarea
- `:number` — number input with optional `min:`/`max:`
- `:select` — dropdown driven by `options: [{label, value}, ...]` (or a function of `Ctx`)
- `:color` — color picker with a Clear button
- `:checkbox` — boolean
- `:custom` — mounts your own LiveComponent (image picker, product
  selector, rich-text editor, anything) by passing `module: MyApp.Foo`

Add `if: fn props -> boolean end` to any field to conditionally
show/hide it.

### Dynamic fields & data

Override `resolve_fields/2` to compute the schema at render time —
e.g. to add fields based on the current `props["variant"]`:

```elixir
def resolve_fields(props, _ctx) do
  fields() ++
    case props["mode"] do
      "advanced" -> [{"target", :text, label: "Target URL"}]
      _ -> []
    end
end
```

Override `resolve_data/2` to compute derived props after every change —
e.g. to look up display data from an id:

```elixir
def resolve_data(_old, new) do
  case new["product_id"] do
    nil -> new
    id -> Map.put(new, "product_name", MyApp.Products.get_name(id))
  end
end
```

Same shapes as Puck.js's `resolveFields` / `resolveData`.

### Page-level settings

Title, description, slug, social image, anything that lives outside the
component tree — declare it as a regular `Athanor.Component` and pass
it as `:page_settings_component` to your editor mount. It auto-renders
at the top of the sidebar and round-trips through `metadata` in your
save handler.

## What Athanor does not do

- **Persistence.** You load/save. Postgres, Mnesia, S3 — your call.
- **HTTP routes.** Mount the LiveView wherever you want.
- **Auth.** Your LiveView's `on_mount` chain runs first.
- **Built-in components.** A small primitive set ships (Button,
  Columns, Divider, Heading, Text) so apps can boot quickly, but real
  apps will replace most of them with branded equivalents.
- **i18n.** The host app handles locale via `Gettext.put_locale/2`
  before Athanor renders.
- **Asset management.** No built-in image picker — register your own
  via a `:custom` field type.

## Documentation

Full API documentation lives on [Hexdocs](https://hexdocs.pm/athanor).

- [CHANGELOG](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

## Why "Athanor"?

The athanor was an alchemist's slow-burning furnace, used for
transmutations that needed a constant, even heat over long periods.
Page builders feel a lot like that.

## License

[MIT](LICENSE) © Zarar Siddiqi
