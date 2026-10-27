# The bake cache (view/part_bake.lobster keeps every part it bakes there): made if missing, and emptied when the bake
# version changes, as the old bakes are never read again. Sourced from the folder this script is in (play.sh, sheet.sh,
# the Deck's run.sh).
version=$(sed -n 's/^let BAKE_VERSION = \([0-9]*\).*/\1/p' view/part_bake.lobster)
mkdir -p bake_cache
if [ "$(cat bake_cache/version 2>/dev/null)" != "$version" ]; then
	find bake_cache -mindepth 1 -delete
	echo "$version" > bake_cache/version
fi
