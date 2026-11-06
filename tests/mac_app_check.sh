#!/bin/sh
# The Mac app (#224): builds it and checks what macOS reads: the games category (Game Mode), the name, the icon, and the
# binary that runs inside Contents/MacOS. Exit 1 on a failure.
here="$(cd "$(dirname "$0")/.." && pwd)"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
"$here/tools/mac/make_app.sh" > /dev/null || { echo "FAIL make_app.sh"; exit 1; }
app="$here/build/mac/Age of Anything.app"
plist="$app/Contents/Info.plist"
fail=0
is() { # is <key> <value>
	got="$(plutil -extract "$1" raw -o - "$plist" 2>/dev/null)"
	[ "$got" = "$2" ] || { echo "FAIL $1 is \"$got\", not \"$2\""; fail=1; }
}
is LSApplicationCategoryType public.app-category.games
is CFBundleIdentifier com.casaide.ageofanything
is CFBundleName "Age of Anything"
is CFBundleDisplayName "Age of Anything"
is CFBundlePackageType APPL
is CFBundleIconFile AppIcon
exe="$(plutil -extract CFBundleExecutable raw -o - "$plist" 2>/dev/null)"
[ -x "$app/Contents/MacOS/$exe" ] || { echo "FAIL no launcher \"$exe\""; fail=1; }
[ -x "$app/Contents/MacOS/lobster" ] || { echo "FAIL no lobster in Contents/MacOS"; fail=1; }
cmp -s "$LOBSTER" "$app/Contents/MacOS/lobster" || { echo "FAIL the bundle's lobster isn't the fork's"; fail=1; }
[ -s "$app/Contents/Resources/AppIcon.icns" ] || { echo "FAIL no icon"; fail=1; }
[ -f "$app/Contents/MacOS/data/shaders/default.materials" ] || { echo "FAIL the bundled lobster can't find its data"; fail=1; }
[ -f "$app/Contents/MacOS/modules/std.lobster" ] || { echo "FAIL the bundled lobster can't find its modules"; fail=1; }
(cd "$here/src" && "$app/Contents/MacOS/lobster" --compile-only run_tests.lobster > /dev/null 2>&1) || { echo "FAIL the bundled lobster doesn't compile a program"; fail=1; }
codesign --verify "$app/Contents/MacOS/lobster" 2>/dev/null || { echo "FAIL the bundled lobster's signature"; fail=1; }
[ "$fail" = 0 ] && echo "mac app: ok"
exit $fail
