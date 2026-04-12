#!/usr/bin/env bash
# apply-layout.sh — idempotent layout handler
#
# CASE 1: center 3/7 via padding  |  CASE 2: 1:1 tile
# CASE 3: 2:3:2 tile              |  CASE 4+: balanced
#
# Hot path: no commands. Cold path: 1 round-trip to fixpoint.

set -euo pipefail

LOCKDIR="/tmp/yabai-layout.lock"
mkdir "$LOCKDIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

PAD_DEFAULT=6
TOL=5

abs_diff() { local d=$(( ${1%.*} - ${2%.*} )); echo ${d#-}; }

# Focused space
space_json=$(yabai -m query --spaces --space 2>/dev/null) || exit 0
space=$(echo "$space_json" | jq -r '.index // empty')
disp=$(echo "$space_json" | jq -r '.display // empty')
[ -n "$space" ] || exit 0

# Primary display gate (widest)
displays_json=$(yabai -m query --displays 2>/dev/null)
primary=$(echo "$displays_json" | jq -r \
  'if type=="array" and length>0 then (sort_by(-.frame.w) | .[0].index) else empty end' 2>/dev/null)
[ -z "$primary" ] || [ "$disp" = "$primary" ] || exit 0

# Tiled visible windows sorted by x
wins=$(yabai -m query --windows --space "$space" | jq '[.[] | select(
  ."is-floating"  == false and
  ."is-minimized" == false and
  ."is-hidden"    == false and
  ."is-visible"   == true
)] | sort_by(.frame.x)')
n=$(echo "$wins" | jq 'length')

pad_left=$(yabai -m config --space "$space" left_padding)

# Center padding for CASE 1
disp_w=$(echo "$displays_json" | jq --argjson d "${disp:-1}" \
  '[.[] | select(.index == $d)][0].frame.w // 0' 2>/dev/null)
disp_w=${disp_w%.*}
pad_center=$(( (disp_w * 2 + 7) / 7 ))

# Restore default padding when leaving CASE 1
if [ "$n" -ge 2 ] && [ "$pad_left" -ne "$PAD_DEFAULT" ]; then
  yabai -m config --space "$space" left_padding "$PAD_DEFAULT"
  yabai -m config --space "$space" right_padding "$PAD_DEFAULT"
fi

case "$n" in
  0) exit 0 ;;

  1)
    [ "$pad_left" = "$pad_center" ] && exit 0
    yabai -m config --space "$space" left_padding "$pad_center"
    yabai -m config --space "$space" right_padding "$pad_center"
    ;;

  2)
    w1=$(echo "$wins" | jq -r '.[0].id')
    w2=$(echo "$wins" | jq -r '.[1].id')
    width1=$(echo "$wins" | jq -r '.[0].frame.w')
    width2=$(echo "$wins" | jq -r '.[1].frame.w')

    [ "$(abs_diff "$width1" "$width2")" -lt "$TOL" ] && exit 0

    split=$(echo "$wins" | jq -r '.[0]."split-type"')
    child1=$(echo "$wins" | jq -r '.[0]."split-child"')
    child2=$(echo "$wins" | jq -r '.[1]."split-child"')

    if [ "$split" = "vertical" ] && [ "$child1" = "first_child" ] && [ "$child2" = "second_child" ]; then
      yabai -m window "$w1" --ratio abs:0.5
    else
      yabai -m window "$w2" --warp "$w1"
      yabai -m window "$w1" --ratio abs:0.5
    fi
    ;;

  3)
    w1=$(echo "$wins" | jq -r '.[0].id')
    w2=$(echo "$wins" | jq -r '.[1].id')
    w3=$(echo "$wins" | jq -r '.[2].id')
    width1=$(echo "$wins" | jq -r '.[0].frame.w')
    width2=$(echo "$wins" | jq -r '.[1].frame.w')
    width3=$(echo "$wins" | jq -r '.[2].frame.w')
    total=$(echo "$wins" | jq '[.[].frame.w] | add')
    total=${total%.*}; w1i=${width1%.*}; w2i=${width2%.*}; w3i=${width3%.*}

    # Hot path: check 2:3:2 ratio
    if [ "$total" -gt 0 ]; then
      s1=$(( (w1i * 7 + total / 2) / total ))
      s2=$(( (w2i * 7 + total / 2) / total ))
      s3=$(( (w3i * 7 + total / 2) / total ))
      [ "$s1" = "2" ] && [ "$s2" = "3" ] && [ "$s3" = "2" ] && exit 0
    fi

    # Cold path: rebuild tree
    split1=$(echo "$wins" | jq -r '.[0]."split-type"')
    child1=$(echo "$wins" | jq -r '.[0]."split-child"')
    split2=$(echo "$wins" | jq -r '.[1]."split-type"')
    child2=$(echo "$wins" | jq -r '.[1]."split-child"')
    child3=$(echo "$wins" | jq -r '.[2]."split-child"')

    if [ "$split1" = "vertical"   ] && [ "$child1" = "first_child"  ] \
    && [ "$split2" = "horizontal" ] && [ "$child2" = "first_child"  ] \
    &&                                  [ "$child3" = "second_child" ]; then
      yabai -m window "$w1" --ratio abs:0.2857
      yabai -m window "$w2" --ratio abs:0.6000
    else
      yabai -m window "$w3" --warp "$w2"
      sleep 0.05
      yabai -m window "$w1" --ratio abs:0.2857
      yabai -m window "$w2" --ratio abs:0.6000
    fi
    ;;

  *)
    max_w=$(echo "$wins" | jq '[.[].frame.w] | max')
    min_w=$(echo "$wins" | jq '[.[].frame.w] | min')
    [ "$(abs_diff "$max_w" "$min_w")" -lt "$TOL" ] && exit 0
    yabai -m space --balance
    ;;
esac
