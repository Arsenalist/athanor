## Context

`Athanor.Fields` auto-renders a component's `fields/0` schema inside the editor
config panel. Built-in field types live as `defp field(%{type: T} = assigns)`
clauses in `lib/athanor/fields.ex`; the recognized atoms are enumerated in the
`Athanor.Component.field_type` typespec (`lib/athanor/component.ex`). All built-in
inputs render inside one `<form phx-change=...>` and post their `name` →`value`
pairs as form params on every change.

`:select` already solves single-choice selection. Its options come from an
`options:` opt that is **either** a static `[{label, value}, …]` list **or** an
arity-1 function of `Ctx`, resolved lazily at render via the existing private
`resolve_options/2` helper (`lib/athanor/fields.ex`). The current value is matched
with `to_string(props[key]) == to_string(value)` so saved props (which may be
strings or other scalars) compare correctly. A radio group is the same selection
semantics with different chrome — no new value contract, no new resolution path.

## Goals / Non-Goals

**Goals:**

- A built-in `:radio` field for inline single-choice selection over a small option
  set, declared exactly like `:select` (`options:` + `label:` + `if:`).
- Full reuse of `resolve_options/2` and the `:select` selected-value comparison so
  switching `:select` ↔ `:radio` needs no data migration.
- Posts the selected value through the existing fields form like every other
  built-in (shared `name`, no custom event path).

**Non-Goals:**

- Multi-select (that is `:checkbox` groups / a future type) — `:radio` is strictly
  single-choice.
- A `prompt`/empty sentinel option. `:select` offers `prompt:` for "nothing
  selected"; radio groups express "no selection" by simply having none checked, so
  `prompt:` is not carried in v1.
- Per-option disabling, descriptions, or custom layout — out of scope; authors
  needing that use `:custom`.

## Decisions

### D1. New `:radio` clause, reusing the `:select` options machinery

Add `defp field(%{type: :radio} = assigns)` adjacent to the `:select` clause. It
calls the same `resolve_options(assigns.opts[:options], assigns)` and renders one
`<label><input type="radio" name={@key} value={value} checked={…}/> label</label>`
per option. Reusing `resolve_options/2` means the static-list and function-of-Ctx
forms work identically to `:select` for free.

**Alternative considered:** a shared helper rendering either control from one clause.
Rejected — the markup differs enough (a `<select>` vs a group of labeled inputs)
that a shared helper adds indirection without real reuse; the options resolution is
already the shared part and is already factored out.

### D2. Group by shared `name`, value compared as `:select` does

Every radio in the group uses `name={@key}` and `value={value}`; `checked` is
`to_string(@props[@key]) == to_string(value)` — byte-for-byte the `:select`
comparison. Browsers enforce single-selection within a shared `name`, and the fields
form posts the checked `name`→`value` pair, so write-back rides the existing form
with zero new plumbing. Identical comparison rule guarantees a field flipped from
`:select` to `:radio` reads the same saved prop.

**Alternative considered:** a hidden input default (like `:checkbox`'s false-input)
to force a value when nothing is checked. Rejected — `:select` has no such default
and "no selection" is a legitimate state; adding one would diverge from `:select`'s
semantics and surprise authors switching types.

### D3. Typespec + docs updated alongside

Add `:radio` to `@type field_type` and the built-in-types list in the
`Athanor.Component` moduledoc, and to the `Athanor.Fields` moduledoc type list, so
the recognized-types surface stays the single source of truth (mirrors how `:asset`
was added).

## Risks / Trade-offs

- **[Author uses `:radio` for a large option set] → Guidance only.** Radio groups
  read poorly past ~5 options; `:select` remains the right tool there. Documented in
  the field-type list, not enforced.
- **[No empty/`prompt` option] → Acceptable for v1.** Unlike `:select`, a radio group
  cannot offer an explicit "none" row. If a clearable single-choice is later needed,
  add an opt-in `prompt:`/clear affordance without breaking existing declarations.
- **[`if:` conditional fields] → Free.** `:radio` flows through the same field
  pipeline, so the existing `if: fn props -> boolean end` omission behavior applies
  with no extra work; covered by a test.

## Migration Plan

Additive, no migration. `:radio` ships unused until a component opts in. Hosts may
convert suitable `:select` fields to `:radio` one at a time; because the value
contract and comparison are identical, no saved data changes. Rollback is reverting
the `:radio` clause and typespec entry — nothing else references it.
