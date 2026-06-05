## Why

When the `lock` query param is set on the product event page, the variant list is narrowed to the single variant named by `variant_id`. This hides the other variants (e.g. different ticket tiers / price options) that belong to the *same showtime*. A locked link should still let the buyer choose among every option for that showtime — it should only hide *other* showtimes.

## What Changes

- When `lock` is active, narrow the displayed variants to **all variants sharing the locked variant's `starts_at_utc`**, instead of only the single `variant_id` variant.
- Keep the selected/scroll-target variant as the `variant_id` variant so the locked link still highlights the originally-linked option.
- Update lock-dependent UI state (`other_purchasable_non_addon_variants_exist?`, `locked_variant_sold_out?`, "View other showtimes" CTA) to reason about the locked **showtime group** rather than the single variant.
- Variants with a `nil` `starts_at_utc` (add-ons) remain excluded from showtime grouping; lock fallback behavior (unknown `variant_id` → show all) is unchanged.

## Capabilities

### New Capabilities
- `event-showtime-lock`: Behavior of the product event page when the `lock` query param is present — which variants are displayed, which is selected, and the lock-related UI affordances.

### Modified Capabilities
<!-- none — no existing spec covers this behavior -->

## Impact

- Code: `amplify/lib/amplify_web/live/event.ex` (`mount/3` lock branch, lines ~74–198), lock-related socket assigns.
- Template: `amplify/lib/amplify_web/live/event.html.heex` ("View other showtimes" / clear-lock CTA, lines ~118–134).
- No schema, migration, or API changes. `ProductVariant.starts_at_utc` is read-only here.
- Affects only the `lock=1`/`lock=true` rendering path; non-locked event pages unchanged.
