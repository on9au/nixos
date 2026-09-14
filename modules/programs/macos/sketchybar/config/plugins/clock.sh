#!/bin/sh
# Same format as waybar's clock module ("{:%a %d %b  %H:%M}").
sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"
