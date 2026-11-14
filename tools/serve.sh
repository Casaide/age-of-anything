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

# (this machine's addresses: every IPv4 one but loopback, with its interface, since en0's isn't always the one the Deck
# reaches, e.g. with a VPN or a second network, #490; AOA_SERVE_IP picks one)
addrs="${AOA_SERVE_IP:-}"
if [ -z "$addrs" ]; then
	addrs="$(ifconfig 2>/dev/null | awk '/^[a-z]/ { sub(":", "", $1); i = $1 } $1 == "inet" && $2 != "127.0.0.1" { print $2 " (" i ")" }')"
fi
[ -n "$addrs" ] || addrs="$(hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d')"
[ -n "$addrs" ] || { echo "No network address found: set AOA_SERVE_IP"; exit 1; }
ip="$(echo "$addrs" | head -1 | cut -d' ' -f1)"
url="http://$ip:$PORT"

rm -rf "$out"
mkdir -p "$out"
served=""
if [ -x "$root/build/lobster_linux/run.sh" ]; then
	echo "== Packing the Deck build"
	# (COPYFILE_DISABLE: no macOS ._ files in the archive)
	COPYFILE_DISABLE=1 tar -czf "$out/deck.tar.gz" -C "$root/build" lobster_linux
	sed "s#@URL@#$url#" "$root/tools/deck/install_http.sh" > "$out/deck.sh"
	cksum < "$out/deck.tar.gz" | cut -d' ' -f1 > "$out/version"   # (the Deck's launcher pulls a build whose version differs, #492)
	served="deck"
fi
if [ -f "$root/build/android/age-of-anything.apk" ]; then
	ln -s "$root/build/android/age-of-anything.apk" "$out/age-of-anything.apk"
	served="$served apk"
fi
[ -n "$served" ] || { echo "Nothing built to serve: make deck (or make mobile) first"; exit 1; }

echo
echo "This machine's addresses (use the one on the Deck's network; AOA_SERVE_IP=<ip> make serve bakes it into deck.sh):"
echo "$addrs" | sed 's/^/  /'
echo "  $(hostname -s 2>/dev/null || hostname).local (by name, if the address is unclear)"
case "$served" in *deck*)
	echo
	echo "On the Deck (Desktop mode, Konsole), with the address from above:"
	echo "  curl -fsSL http://<address>:$PORT/deck.sh | AOA_URL=http://<address>:$PORT sh -s -- --run"
	echo "  (first address: curl -fsSL $url/deck.sh | sh -s -- --run)";;
esac
case "$served" in *apk*)
	echo "On a phone, open http://<address>:$PORT/age-of-anything.apk";;
esac
# (the macOS firewall drops incoming connections to python3 unless allowed: the commonest "can't connect")
fw=/usr/libexec/ApplicationFirewall/socketfilterfw
if [ -x "$fw" ]; then
	if "$fw" --getblockall 2>/dev/null | grep -qi "enabled"; then
		echo
		echo "!! The firewall blocks all incoming connections: System Settings > Network > Firewall > Options, turn off 'Block all incoming connections'."
	elif "$fw" --getglobalstate 2>/dev/null | grep -qi "enabled"; then
		echo
		echo "The firewall is on: allow python3 when macOS asks (or add it in System Settings > Network > Firewall > Options)."
	fi
fi
echo
echo "Can't connect? From the Deck: ping <address> (no reply: not the same network, or the firewall). Check here: curl -sI $url/deck.sh"
echo
exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$out"
