#!/bin/sh
# Serves the builds on the local network so the Steam Deck (or a phone) can fetch them (#446). `make serve` runs it.
# Packs what is built into build/serve/:
#   deck.tar.gz   build/lobster_linux (make deck)
#   deck.sh       tools/deck/install_http.sh with this machine's address in it: the Deck runs it
#   age-of-anything.apk   build/android's APK (make mobile), if there is one
# then serves that folder on PORT (8080) until Ctrl-C. Run on the Deck (Desktop mode, Konsole) the line it prints.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8080}"
out="$root/build/serve"

# (this machine's address on the network: the Mac's Wi-Fi or Ethernet, else the first one Linux lists)
ip="${AOA_SERVE_IP:-}"
[ -n "$ip" ] || ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
[ -n "$ip" ] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -n "$ip" ] || { echo "No network address found: set AOA_SERVE_IP"; exit 1; }
url="http://$ip:$PORT"

rm -rf "$out"
mkdir -p "$out"
served=""
if [ -x "$root/build/lobster_linux/run.sh" ]; then
	echo "== Packing the Deck build"
	# (COPYFILE_DISABLE: no macOS ._ files in the archive)
	COPYFILE_DISABLE=1 tar -czf "$out/deck.tar.gz" -C "$root/build" lobster_linux
	sed "s#@URL@#$url#" "$root/tools/deck/install_http.sh" > "$out/deck.sh"
	served="deck"
fi
if [ -f "$root/build/android/age-of-anything.apk" ]; then
	ln -s "$root/build/android/age-of-anything.apk" "$out/age-of-anything.apk"
	served="$served apk"
fi
[ -n "$served" ] || { echo "Nothing built to serve: make deck (or make mobile) first"; exit 1; }

echo
case "$served" in *deck*)
	echo "On the Deck (Desktop mode, Konsole):"
	echo "  curl -fsSL $url/deck.sh | sh"
	echo "  (add '-s -- --run' after sh to start it once installed)";;
esac
case "$served" in *apk*)
	echo "On a phone, open $url/age-of-anything.apk";;
esac
echo
exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$out"
