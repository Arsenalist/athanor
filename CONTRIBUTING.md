# Contributing to Athanor

Thanks for taking the time to contribute. Athanor is a young library —
PRs, bug reports, and design feedback all welcome.

## Development setup

Prerequisites: Elixir `~> 1.17` and Erlang/OTP `~> 26`. The CI matrix
runs against Elixir 1.17 / 1.18 / 1.19 on OTP 26 / 27.

```bash
git clone https://github.com/Arsenalist/athanor.git
cd athanor
mix deps.get
mix test
```

Format before pushing:

```bash
mix format
```

Build docs locally to preview:

```bash
mix docs && open doc/index.html
```

## Branching & PRs

- Branch off `main`. Name branches anything sensible — `fix/`, `feat/`,
  `docs/` prefixes appreciated but not enforced.
- Keep PRs focused: one logical change per PR. Big rewrites get
  reviewed faster when split.
- Every PR needs a `CHANGELOG.md` entry under `## [Unreleased]`. Match
  the section style of prior entries (`### Added` / `### Changed` /
  `### Fixed` / `### Removed`).
- Every PR runs the CI matrix. PRs that don't pass `mix test` or
  `mix format --check-formatted` won't be merged.

## Tests

- Library code (under `lib/athanor/`) needs corresponding tests under
  `test/athanor/`. `lib/athanor/foo.ex` → `test/athanor/foo_test.exs`.
- Tests are `use ExUnit.Case, async: true` by default. Anything that
  touches `Application.get_env/put_env` must reset state in `on_exit`.
- The architecture suite (`test/athanor/tree_architecture_test.exs`)
  enforces the host-agnostic boundary: no `AmplifyWeb.*`, no
  `Amplify.*`, no `Ecto.*`, no `Jason.*` references in `lib/athanor/`.
  Consumer-specific bindings go behind runtime config — see
  `Athanor.Components.Text` for the canonical pattern.

## Semantic versioning policy

While in `0.x`:

- **Minor bump (0.x → 0.x+1)** — any public API change, including
  breaking changes, new behaviour callbacks, new required fields on
  existing structs. Document under `### Changed` or `### Removed`.
- **Patch bump (0.x.y → 0.x.y+1)** — bug fixes, doc improvements,
  internal refactors that don't change public behavior.

Once we hit `1.0`, we switch to strict SemVer (major bumps for breaking
changes).

## Public API contract

Anything documented in `@moduledoc` or with `@doc` is part of the
public contract. Anything else is implementation detail and may change
between patch releases.

Modules under `Athanor.Internal.*` (none today, but reserved) are
explicitly private.

## Boundary rules

Athanor is host-agnostic by design — it must work in any Phoenix app,
not just the one that gave it life. Don't add:

- Runtime dependencies on host applications (Amplify, anyone else's
  app code).
- Ecto / database concerns. Components accept and emit maps.
- JSON encoding/decoding — the caller supplies maps, the caller
  encodes for storage. `Jason` is dev-test only.
- Gettext / locale-specific helpers. The host app handles i18n.

The `lib/athanor/components/` tree may grow with primitive components
(text, heading, button, divider, columns, image). Heavier or
host-specific components (rich-text editors, asset pickers, product
selectors) stay in consumer apps and integrate via the
`Athanor.Component` behaviour + `:custom` field type.

## Releases

Releases happen from `main` only:

1. Update version in `mix.exs`.
2. Promote `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD` in
   `CHANGELOG.md`.
3. Commit + tag (`git tag vX.Y.Z && git push --tags`).
4. `mix hex.publish` from the tagged commit.

## Reporting bugs

Open an issue with:

- Elixir / OTP / `phoenix_live_view` versions.
- Minimal reproduction.
- Expected vs. actual.

Security issues: email instead of opening a public issue — address
listed on the maintainer's GitHub profile.

## License

By contributing, you agree your changes are licensed under the
[MIT License](LICENSE) that covers the rest of the project.
