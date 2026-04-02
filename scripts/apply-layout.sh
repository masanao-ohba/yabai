#!/usr/bin/env bash

# apply-layout.sh
# Automatically adjusts window layout based on the number of managed windows.
#
# Layout rules:
#   1 window  -> float, center at 3/7 width (--grid 1:7:2:0:3:1)
#   2 windows -> BSP 1:1
#   3 windows -> BSP 2:3:2 (root ratio 2/7, sub-root ratio 3/5)
#   4+ windows -> BSP auto-balance

# --- Debounce ---
LOCK_FILE="/tmp/yabai-apply-layout.lock"
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
  if [ "$lock_age" -lt 1 ]; then
    exit 0
  fi
fi
touch "$LOCK_FILE"

sleep 0.3

# --- Only apply layout on the widest display (primary) ---
DISPLAY_INDEX=$(yabai -m query --spaces --space | jq -r '.display')
PRIMARY_DISPLAY=$(yabai -m query --displays | jq -r 'sort_by(-.frame.w) | .[0].index')
if [ "$DISPLAY_INDEX" != "$PRIMARY_DISPLAY" ]; then
  rm -f "$LOCK_FILE"
  exit 0
fi

# --- Marker file for tracking our own floated window ---
MARKER_FILE="/tmp/yabai-single-float.id"
# --- Window count cache to skip unnecessary re-layouts ---
COUNT_FILE="/tmp/yabai-layout-count"

# --- Query windows ---
SPACE_INDEX=$(yabai -m query --spaces --space | jq -r '.index')

# Tiled windows only (excludes manage=off floating windows like Zoom, Finder)
TILED_JSON=$(yabai -m query --windows --space "$SPACE_INDEX" \
  | jq '[.[] | select(."is-floating" == false and ."is-minimized" == false and ."is-hidden" == false and ."is-visible" == true)] | sort_by(.frame.x)')
TILED_COUNT=$(echo "$TILED_JSON" | jq 'length')

# Skip if window count hasn't changed (prevents flicker on tab switches etc.)
# Only skip when not called manually (manual call via skhd won't have YABAI_SIGNAL env)
CURRENT_KEY="${SPACE_INDEX}:${TILED_COUNT}"
if [ -f "$MARKER_FILE" ]; then
  FLOATED_ID=$(cat "$MARKER_FILE" 2>/dev/null)
  FLOATED_EXISTS=$(yabai -m query --windows --space "$SPACE_INDEX" \
    | jq --arg id "$FLOATED_ID" '[.[] | select(.id == ($id | tonumber) and ."is-floating" == true)] | length' 2>/dev/null)
  if [ "$FLOATED_EXISTS" = "1" ]; then
    CURRENT_KEY="${SPACE_INDEX}:$(( TILED_COUNT + 1 ))"
  fi
fi
PREV_KEY=$(cat "$COUNT_FILE" 2>/dev/null)
if [ "$CURRENT_KEY" = "$PREV_KEY" ] && [ -z "$YABAI_MANUAL" ]; then
  rm -f "$LOCK_FILE"
  exit 0
fi
echo "$CURRENT_KEY" > "$COUNT_FILE"

# Check if we have a previously floated single window
OUR_FLOAT_ID=""
if [ -f "$MARKER_FILE" ]; then
  OUR_FLOAT_ID=$(cat "$MARKER_FILE")
  EXISTS=$(yabai -m query --windows --space "$SPACE_INDEX" \
    | jq --arg id "$OUR_FLOAT_ID" '[.[] | select(.id == ($id | tonumber) and ."is-floating" == true)] | length')
  if [ "$EXISTS" -ne 1 ]; then
    OUR_FLOAT_ID=""
    rm -f "$MARKER_FILE"
  fi
fi

# Total count = tiled + our floated window (if any)
TOTAL_COUNT="$TILED_COUNT"
if [ -n "$OUR_FLOAT_ID" ]; then
  TOTAL_COUNT=$(( TILED_COUNT + 1 ))
fi

# Nothing to do
if [ "$TOTAL_COUNT" -eq 0 ]; then
  rm -f "$LOCK_FILE"
  exit 0
fi

# --- Helper: unfloat our previously floated window ---
unfloat_our_window() {
  if [ -n "$OUR_FLOAT_ID" ]; then
    yabai -m window "$OUR_FLOAT_ID" --toggle float
    rm -f "$MARKER_FILE"
    OUR_FLOAT_ID=""
    sleep 0.1
  fi
}

# --- Apply layout ---
case "$TOTAL_COUNT" in
  1)
    # Single window: float and center at 3/7 width
    if [ -n "$OUR_FLOAT_ID" ]; then
      # Already floated by us, just reposition
      yabai -m window "$OUR_FLOAT_ID" --grid 1:7:2:0:3:1
    else
      # Float the tiled window
      WIN_ID=$(echo "$TILED_JSON" | jq -r '.[0].id')
      yabai -m window "$WIN_ID" --toggle float
      yabai -m window "$WIN_ID" --grid 1:7:2:0:3:1
      echo "$WIN_ID" > "$MARKER_FILE"
    fi
    ;;

  2)
    # Two windows: unfloat if needed, BSP 1:1
    unfloat_our_window

    # Re-query tiled windows
    sleep 0.1
    TILED=$(yabai -m query --windows --space "$SPACE_INDEX" \
      | jq '[.[] | select(."is-floating" == false and ."is-minimized" == false and ."is-hidden" == false and ."is-visible" == true)] | sort_by(.frame.x)')
    TILED_COUNT=$(echo "$TILED" | jq 'length')

    if [ "$TILED_COUNT" -ge 2 ]; then
      FIRST_ID=$(echo "$TILED" | jq -r '.[0].id')
      SECOND_ID=$(echo "$TILED" | jq -r '.[1].id')
      yabai -m window "$SECOND_ID" --warp "$FIRST_ID"
      sleep 0.1
      yabai -m window "$FIRST_ID" --ratio abs:0.5
    fi
    ;;

  3)
    # Three windows: unfloat if needed, BSP 2:3:2
    unfloat_our_window

    sleep 0.1
    TILED=$(yabai -m query --windows --space "$SPACE_INDEX" \
      | jq '[.[] | select(."is-floating" == false and ."is-minimized" == false and ."is-hidden" == false and ."is-visible" == true)] | sort_by(.frame.x)')
    TILED_COUNT=$(echo "$TILED" | jq 'length')

    if [ "$TILED_COUNT" -ge 3 ]; then
      WIN1=$(echo "$TILED" | jq -r '.[0].id')
      WIN2=$(echo "$TILED" | jq -r '.[1].id')
      WIN3=$(echo "$TILED" | jq -r '.[2].id')

      # Rebuild BSP tree: WIN1 alone on left, WIN2+WIN3 grouped on right
      # Warp WIN3 next to WIN2 to create subtree [WIN2, WIN3]
      yabai -m window "$WIN3" --warp "$WIN2"
      sleep 0.1

      # Set ratios: root = 2/7 (WIN1 is left), sub-root = 3/5 (WIN2 is center)
      yabai -m window "$WIN1" --ratio abs:0.2857
      yabai -m window "$WIN2" --ratio abs:0.6000
    fi
    ;;

  *)
    # 4+ windows: unfloat and auto-balance
    unfloat_our_window
    yabai -m space --balance
    ;;
esac

rm -f "$LOCK_FILE"
