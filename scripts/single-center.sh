#!/usr/bin/env bash
# single-center.sh — toggle float-center for single visible window
# Float → tile, tile → float at grid 1:7:2:0:3:1 (3/7 center)

space=$(yabai -m query --spaces --space | jq -r '.index')
visible=$(yabai -m query --windows --space "$space" \
  | jq '[.[] | select(."is-minimized" == false and ."is-hidden" == false and ."is-visible" == true)]')

[ "$(echo "$visible" | jq 'length')" -eq 1 ] || exit 0

wid=$(echo "$visible" | jq -r '.[0].id')
floating=$(echo "$visible" | jq -r '.[0]."is-floating"')

yabai -m window "$wid" --toggle float
[ "$floating" = "false" ] && yabai -m window "$wid" --grid 1:7:2:0:3:1
