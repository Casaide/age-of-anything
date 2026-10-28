#!/bin/sh
# The golden files: what the game makes (races, match starts, every part's and building's model, research effects in
# words) held to golden/<section>.txt, recorded when they matched Godot's line for line. A change that's meant goes in
# with "update" (then look at the diff before committing it).
#   ./golden.sh [update] [section ...]       sections: races races_anything starts models buildings effects
cd "$(dirname "$0")"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
update=0
[ "$1" = update ] && { update=1; shift; }
sections="$*"
[ -z "$sections" ] && sections="races races_anything starts models buildings effects"
PROMPTS_FILE=golden/prompts.txt
mkdir -p golden
out=${TMPDIR:-/tmp}/aoa_golden
mkdir -p "$out"
bad=0
for s in $sections; do
	case "$s" in
		races) { tr '\n' '\0' < "$PROMPTS_FILE" | xargs -0 "$LOBSTER" races.lobster -- default; } 2>&1 | grep -v warning > "$out/$s.txt" ;;
		races_anything) { tr '\n' '\0' < "$PROMPTS_FILE" | xargs -0 "$LOBSTER" races.lobster -- anything; } 2>&1 | grep -v warning > "$out/$s.txt" ;;
		*) "$LOBSTER" golden.lobster -- "$s" 2>&1 | grep -v warning > "$out/$s.txt" ;;
	esac
	if [ $update = 1 ]; then
		cp "$out/$s.txt" "golden/$s.txt"
		echo "recorded $s ($(wc -l < "golden/$s.txt" | tr -d ' ') lines)"
	elif cmp -s "$out/$s.txt" "golden/$s.txt"; then
		echo "same  $s ($(wc -l < "golden/$s.txt" | tr -d ' ') lines)"
	else
		echo "DIFF  $s: $(diff "golden/$s.txt" "$out/$s.txt" | grep -c '^>') lines differ (diff golden/$s.txt $out/$s.txt)"
		bad=$((bad + 1))
	fi
done
[ $bad -eq 0 ]
