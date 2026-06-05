## Context

The product event page (`AmplifyWeb.Event.mount/3`, `lib/amplify_web/live/event.ex`) supports a `lock` query param used by shareable links that point at a specific showtime/variant. Today, when `lock_active?` is true, the variant list is filtered to the single `params_variant_id`:

```elixir
filtered_variants =
  if lock_active? do
    Enum.filter(filtered_variants, &(&1.id == params_variant_id))
  else
    filtered_variants
  end
```

Each showtime can have multiple variants (e.g. price tiers / ticket types) that share the same `starts_at_utc`. Locking to a single `variant_id` therefore hides the other purchasing options for that same showtime, which is not the intent — lock should scope to a *showtime*, not a *variant*.

`ProductVariant.starts_at_utc` (`lib/amplify/models/product_variant.ex:10`) is a `utc_datetime`. Add-on variants are already excluded upstream (`is_add_on` reject + `nil` `starts_at_utc` filtered by `ShowtimeListHelpers`).

## Goals / Non-Goals

**Goals:**
- When lock is active, show all displayable variants sharing the locked variant's `starts_at_utc`.
- Preserve the originally-linked variant as selected / scroll target.
- Keep lock-dependent UI (`other_purchasable_non_addon_variants_exist?`, `locked_variant_sold_out?`, clear-lock CTA) semantically correct relative to the showtime group.

**Non-Goals:**
- Changing the non-locked rendering path.
- Changing how lock URLs are generated (`EventListData.build_event_link`).
- Schema, migration, or grouping by anything other than `starts_at_utc`.

## Decisions

**Group by `starts_at_utc` value equality.** After confirming `lock_active?`, resolve the locked variant, capture its `starts_at_utc`, and filter `filtered_variants` to those with an equal `starts_at_utc`. Use `DateTime.compare/2 == :eq` for comparison rather than `==` to avoid microsecond/struct-precision mismatches.

```elixir
filtered_variants =
  if lock_active? do
    locked = Enum.find(filtered_variants, &(&1.id == params_variant_id))
    Enum.filter(filtered_variants, fn v ->
      v.starts_at_utc != nil and
        DateTime.compare(v.starts_at_utc, locked.starts_at_utc) == :eq
    end)
  else
    filtered_variants
  end
```

*Alternative considered:* group by a higher-level showtime id. Rejected — there is no single showtime entity keying these variants; `starts_at_utc` is the de-facto showtime key already used across `ShowtimeListHelpers`.

**Redefine `other_purchasable_non_addon_variants_exist?` against the locked `starts_at_utc`.** Currently (lines 86–90) it checks for a purchasable variant with `id != params_variant_id`. After the change, sibling variants of the same showtime are in the list, so the old predicate would wrongly report "other showtimes exist." Recompute it against the *pre-narrowed* variant list: true iff a purchasable, non-add-on variant exists whose `starts_at_utc` differs from the locked variant's. This must be computed before `filtered_variants` is narrowed (it needs the full list).

**`selected_variant_id` / `scroll_target_variant_id` unchanged.** They already key off `variant_exists_in_filtered?` / `params_variant_id`, which still holds since the locked variant remains in the narrowed list.

**`locked_variant_sold_out?` unchanged in shape.** It looks up `params_variant_id` within `filtered_variants`; the locked variant is still present, so the existing `Enum.find` continues to work.

## Risks / Trade-offs

- **Two variants legitimately share a `starts_at_utc` across different logical showtimes** → They would be grouped together. Acceptable: identical start time is exactly the grouping intent for this page; no showtime id exists to distinguish them.
- **`nil` `starts_at_utc` on the locked variant** → Cannot happen for a locked variant: it must be in `filtered_variants`, which `ShowtimeListHelpers.get_displayable_variants` already strips of `nil` `starts_at_utc`. Guarded anyway with the `v.starts_at_utc != nil` clause.
- **Ordering of computation** → `other_purchasable_non_addon_variants_exist?` must be derived from the full list before narrowing; reordering the existing block is required. Mitigation: compute it in the same place it is today (before the narrowing reassignment).

## Migration Plan

Pure rendering-logic change, no data migration. Deploy is a single code change; rollback is reverting the `event.ex` diff. No feature flag needed — behavior change is scoped to the `lock` path and is backward-compatible for single-variant showtimes.
