# CLAUDE.md

## Layout Specification (invariant)

Layout applied per managed window count on the primary (widest) display.

| windows | layout | method |
|---|---|---|
| 1 | center 3/7 width | space padding = display_w * 2/7 |
| 2 | 1:1 | tile, ratio 0.5 |
| 3 | 2:3:2 | tile, ratios 0.2857 / 0.6000 |
| 4+ | balanced | tile, space --balance |

- Auto-transition on window count change
- No flicker, no high CPU
- Same layout via manual trigger (skhd)

## Design Constraints (invariant)

| ID | Constraint |
|---|---|
| D1 | Idempotent: repeated execution on same state emits zero commands |
| D2 | yabai window/space commands do not fire signals; loops originate from app AX reactions |
| D3 | Hot path (layout matches): no yabai commands → no AX writeback → no loop |
| D4 | Cold path (mismatch): converges to fixpoint in at most 1 round-trip |
| D5 | `auto_balance on` forbidden — breaks CASE 3 asymmetric ratios |

## Repository Structure

- `yabairc` — global settings, space settings, app rules, signal registration
- `scripts/apply-layout.sh` — layout handler (signal + manual trigger)
- `scripts/single-center.sh` — manual float-center toggle for single window
- `scripts/center-window.sh` — swap focused ↔ center in 3-window layout

## Key Facts

- BSP layout, `split_ratio 0.50`, `auto_balance off`
- Opacity: 85% normal / 100% active
- Border: removed in v7 (use JankyBorders)
- Mouse modifier: `fn`
- Primary display: `yabai -m query --displays | jq 'sort_by(-.frame.w) | .[0]'`

## Operations

- **Reload**: `yabai --restart-service`
- **Test**: `./yabairc`
- **Syntax check**: `sh -n yabairc`

## App Rules

`yabai -m rule --add app="^Name$" [manage=off] [layer=above] [sticky=on]`
