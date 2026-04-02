#!/usr/bin/env bash

# center-window.sh
# Swaps the currently focused window into the center position.
# Only operates when exactly 3 tiled windows are on the focused space.

SPACE_INDEX=$(yabai -m query --spaces --space | jq -r '.index')

TILED=$(yabai -m query --windows --space "$SPACE_INDEX" \
  | jq '[.[] | select(."is-floating" == false and ."is-minimized" == false and ."is-hidden" == false and ."is-visible" == true)] | sort_by(.frame.x)')

TILED_COUNT=$(echo "$TILED" | jq 'length')

if [ "$TILED_COUNT" -ne 3 ]; then
  echo "center-window: only works with exactly 3 tiled windows (found $TILED_COUNT)"
  exit 0
fi

FOCUSED_ID=$(yabai -m query --windows --window | jq -r '.id')
CENTER_ID=$(echo "$TILED" | jq -r '.[1].id')

if [ "$FOCUSED_ID" = "$CENTER_ID" ]; then
  echo "center-window: focused window is already in the center"
  exit 0
fi

# Swap focused window with center window
yabai -m window "$FOCUSED_ID" --swap "$CENTER_ID"

# Swap preserves the BSP tree structure and ratios, so no need to re-apply layout.
