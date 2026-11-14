# Builds for every platform, and a way to hand them to the Steam Deck (#446). Each target only calls the platform's own
# script, which says what it needs at its top. `make` alone lists the targets.
#   make mac | deck | mobile | all     build (mac bakes the shipped art first: make bake)
#   make serve                          serve what is built on the local network (the Deck fetches it from here)
#   make deck serve                     build the Deck's and serve it
# Settings: LOBSTER (the Mac's lobster binary), LOBSTER_SRC (the Lobster checkout the Deck and Android builds compile),
# PORT (serve's port).

LOBSTER ?= $(HOME)/Dev/lobster/bin/lobster
LOBSTER_SRC ?= $(HOME)/Dev/lobster
PORT ?= 8080
export LOBSTER LOBSTER_SRC PORT

.PHONY: help all mac bake deck mobile android serve

help:
	@echo "make mac      macOS: build/mac/Age of Anything.app (a dev build that runs this checkout; tools/mac/make_app.sh)"
	@echo "make bake     the shipped props and buildings, baked into src/baked/ for both densities (src/prebake.sh); make mac runs it"
	@echo "make deck     Steam Deck: build/lobster_linux (Lobster for Linux from CI's release, else built in podman/docker; src/deck/build.sh)"
	@echo "make mobile   Android: build/android/age-of-anything.apk (needs the SDK, NDK, JDK 17+; src/android/build.sh)"
	@echo "make all      all three"
	@echo "make serve    serve what is built on port $(PORT), and print the line to run on the Deck (tools/serve.sh)"
	@echo "Settings: LOBSTER=$(LOBSTER) LOBSTER_SRC=$(LOBSTER_SRC) PORT=$(PORT)"

all: mac deck mobile

mac: bake
	tools/mac/make_app.sh

bake:
	src/prebake.sh

deck:
	src/deck/build.sh

mobile android:
	src/android/build.sh

serve:
	tools/serve.sh
