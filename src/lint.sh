#!/bin/sh
# Formatting and compiler warnings, as one check. ./lint.sh [--fix]; exit 1 on anything found.
#   - lobsterfmt must leave every file of every program in src/ as it is; --fix writes it.
#   - every program compiles with no warnings. A compile error counts too. A "use let" only counts if nothing under src/ assigns that name: a shared
#     global set only by another program looks unassigned in the programs that don't include that code.
cd "$(dirname "$0")"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
LOBSTERFMT="${LOBSTERFMT:-$(dirname "$LOBSTER")/lobsterfmt}"
out="$(mktemp)"
assigned="$(mktemp)"
trap 'rm -f "$out" "$assigned"' EXIT
if [ "$1" = "--fix" ]; then
	"$LOBSTERFMT" -w *.lobster >> "$out" 2>&1
else
	"$LOBSTERFMT" -l *.lobster 2>&1 | sed 's/^/not formatted: /' >> "$out"
fi
# Every name assigned anywhere, in one pass: a pass each, for hundreds of names, was nearly all of lint's time (#245).
grep -rhoE --include='*.lobster' '(^|[^.a-zA-Z0-9_])[a-zA-Z0-9_]+ *(=[^=]|\+=|-=|\*=|/=|\+\+|--)' . | sed -E 's/^[^a-zA-Z0-9_]//; s/ *(=.|\+=|-=|\*=|\/=|\+\+|--)$//' | sort -u > "$assigned"
for prog in *.lobster; do
	"$LOBSTER" --compile-only "$prog" 2>&1 | grep 'warning:\|error:' | while IFS= read -r line; do
		name="$(printf '%s\n' "$line" | sed -n 's/.*use `let` to declare `\([a-zA-Z0-9_]*\)`.*/\1/p')"
		if [ -n "$name" ] && grep -Fxq "$name" "$assigned"; then
			continue
		fi
		printf '%s: %s\n' "$prog" "$line"
	done >> "$out"
done
sort -u "$out"
n="$(sort -u "$out" | wc -l | tr -d ' ')"
echo "lint: $n problems"
[ "$n" = 0 ]
