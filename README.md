# Athanor

Host-agnostic page builder library for the BEAM. Today: a tree-manipulation
core. Next: components, renderer, adapters, LiveView editor, MJML/email
target.

This lives as a path-dependency mix project inside Amplify (`{:athanor, path:
"athanor"}`) and is designed to be extractable as a standalone OSS library —
it has **no** reference to `Amplify.*`, `AmplifyWeb.*`, `Phoenix.*`, `Ecto.*`,
or gettext. The boundary is enforced both physically (this subdirectory does
not depend on the parent app) and by an architecture test
(`test/athanor/tree_architecture_test.exs`).

JSON encoding and decoding are the caller's responsibility. `Athanor.Tree`
accepts and returns already-decoded Elixir maps.

## Verify standalone

```sh
cd athanor
mix compile
mix test
```

No hex deps at this step — only stdlib.

## Status

Step 1 of the Athanor extraction: `Athanor.Tree` only. No callers wired up
inside Amplify yet. Subsequent steps introduce a renderer, component
behaviour, adapters, and an editor LiveView.
