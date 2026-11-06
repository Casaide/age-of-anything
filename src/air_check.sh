#!/bin/sh
# A click on an aircraft where it's drawn takes it, and one on the ground under it doesn't (#185). Silent.
#   src/air_check.sh
cd "$(dirname "$0")/.." || exit 1
exec ./play.sh lobby mods:ww2 rules:ww2_duel "races:sherman|panzer" army:2 airtest mute
