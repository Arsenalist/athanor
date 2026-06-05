## 1. Variant grouping logic

- [x] 1.1 In `event.ex` `mount/3`, resolve the locked variant (`Enum.find` by `params_variant_id`) before the narrowing step
- [x] 1.2 Replace the `lock_active?` narrowing (lines ~92–97) to filter `filtered_variants` to variants whose `starts_at_utc` equals the locked variant's, using `DateTime.compare/2 == :eq` and guarding `nil`
- [x] 1.3 Recompute `other_purchasable_non_addon_variants_exist?` against the full (pre-narrowed) list: true iff a purchasable, non-add-on variant exists with a `starts_at_utc` different from the locked variant's

## 2. Verify downstream state

- [x] 2.1 Confirm `selected_variant_id` / `scroll_target_variant_id` still resolve to `params_variant_id` (locked variant remains in narrowed list)
- [x] 2.2 Confirm `locked_variant_sold_out?` still finds `params_variant_id` in `filtered_variants`
- [x] 2.3 Confirm vertical-mode sold-out sort still applies to the now-larger locked variant set

## 3. Tests

- [x] 3.1 Test: lock with a showtime that has multiple same-`starts_at_utc` variants shows all of them, selected = `variant_id`
- [x] 3.2 Test: lock with a single-variant showtime shows only that variant
- [x] 3.3 Test: variants from other showtimes are excluded under lock
- [x] 3.4 Test: unknown `variant_id` under lock falls back to showing all showtimes
- [x] 3.5 Test: `other_purchasable_non_addon_variants_exist?` true when a purchasable variant exists at a different `starts_at_utc`, false when all purchasable variants share the locked `starts_at_utc`

## 4. Manual verification

- [x] 4.1 Load a locked event link with a multi-variant showtime; verify all options render and the "View other showtimes" CTA behaves correctly when the locked variant is sold out
