## ADDED Requirements

### Requirement: Lock displays all variants of the locked showtime

When the `lock` query param is active (`lock=1` or `lock=true`) and `variant_id` matches a displayable variant, the event page SHALL display every displayable variant whose `starts_at_utc` equals the locked variant's `starts_at_utc` — not only the single `variant_id` variant. Variants belonging to other showtimes SHALL be hidden.

#### Scenario: Showtime has multiple variants

- **WHEN** the page loads with `lock=1` and `variant_id` pointing to a variant whose showtime has 3 displayable variants (same `starts_at_utc`)
- **THEN** all 3 variants for that showtime are displayed
- **AND** variants belonging to any other `starts_at_utc` are not displayed

#### Scenario: Showtime has a single variant

- **WHEN** the page loads with `lock=1` and the locked variant's showtime has only that one displayable variant
- **THEN** only that variant is displayed

### Requirement: Locked link preserves the originally selected variant

When lock is active, the system SHALL keep the `variant_id` variant as the selected and scroll-target variant, so the locked link still highlights the originally-linked option even when sibling variants of the same showtime are now shown.

#### Scenario: Selected variant stays the linked one

- **WHEN** the page loads with `lock=1` and `variant_id` set, and the showtime has multiple variants
- **THEN** the selected variant is the `variant_id` variant
- **AND** the page scrolls to the `variant_id` variant

### Requirement: Unknown locked variant falls back to all showtimes

When `lock` is set but `variant_id` is missing or does not match any displayable variant, the system SHALL ignore the lock and display all displayable variants for all showtimes (existing fallback behavior).

#### Scenario: variant_id not found

- **WHEN** the page loads with `lock=1` and a `variant_id` that matches no displayable variant
- **THEN** lock is treated as inactive
- **AND** all displayable variants for all showtimes are displayed

### Requirement: Other-showtimes affordance reflects the locked group

The "View other showtimes" / clear-lock affordance SHALL be driven by whether purchasable variants exist **outside** the locked showtime group, rather than whether any variant other than `variant_id` is purchasable. The `other_purchasable_non_addon_variants_exist?` state SHALL be true only when at least one purchasable, non-add-on variant exists with a `starts_at_utc` different from the locked variant's.

#### Scenario: Purchasable variant exists at another showtime

- **WHEN** lock is active, the locked variant is sold out, and another showtime has a purchasable variant
- **THEN** the "View other showtimes" CTA is shown

#### Scenario: Only the locked showtime has purchasable variants

- **WHEN** lock is active and the only purchasable variants share the locked variant's `starts_at_utc`
- **THEN** the "View other showtimes" CTA is not shown
