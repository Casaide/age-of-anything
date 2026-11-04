#!/bin/sh
# An Android build (arm64 phones and tablets, OpenGL ES 3): the game compiled to C++ by Lobster, built with the NDK
# into Lobster's Android template (SDL), the game's data, assets and pictures packed into the APK.
#   src/android/build.sh [out dir]   (default build/android; the APK is <out>/age-of-anything.apk)
# Needs the Android SDK and NDK (ANDROID_HOME, default ~/Library/Android/sdk) and a JDK 17 or newer. Gradle and the
# Android plugin come from ~/.gradle (offline: the versions below are the ones cached on this Mac).
# The buildings and props ship baked (src/prebake.sh); a race's own parts bake on the device, kept with its saves and
# races in the app's external files folder. Install with: adb install -r build/android/age-of-anything.apk
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
root="$(cd "$here/.." && pwd)"
out="${1:-$root/build/android}"
LOBSTER_SRC="${LOBSTER_SRC:-$HOME/Dev/lobster}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
NDK_VERSION="${NDK_VERSION:-29.0.14206865}"
GRADLE_VERSION="${GRADLE_VERSION:-9.6.1}"
AGP_VERSION="${AGP_VERSION:-9.3.1}"

echo "== The code, with its paths for the APK (../data -> data: the APK's assets are one folder)"
stage="$out/stage"
rm -rf "$stage"
mkdir -p "$stage"
rsync -a --exclude 'bake_cache' --exclude 'baked' --exclude 'deck' --exclude 'android' --exclude 'golden' --exclude 'model/mods/*' \
	--exclude '*.sav' --exclude 'memory_leaks.txt' --exclude 'saves' --exclude 'races' "$here/" "$stage/"
find "$stage" -name '*.lobster' -exec sed -E -i '' 's#"\.\./(data|assets|mods|mods_private|docs)#"\1#g' {} +

generated="$LOBSTER_SRC/dev/compiled_lobster/src/compiled_lobster.cpp"
proj="$out/dev/android-project"
mkdir -p "$out/dev/compiled_lobster/src"

echo "== The Android project"
# Lobster's template finds the engine at ../../.. from its jni folder: the engine's folders linked beside it.
for d in external include; do ln -sfn "$LOBSTER_SRC/dev/$d" "$out/dev/$d"; done
rm -rf "$out/dev/src"
rsync -a "$LOBSTER_SRC/dev/src/" "$out/dev/src/"
rm -rf "$proj"
rsync -a --exclude 'build' --exclude '.gradle' --exclude 'app/src/main/assets' "$LOBSTER_SRC/dev/android-project/" "$proj/"
mkdir -p "$proj/app/src/main/java/com/ageofanything/game"
# SDL's Java side, matched to the SDL Lobster builds in (3.4.5: release-3.4.4's files, every native method checked)
rm -rf "$proj/app/src/main/java/org/libsdl/app"
mkdir -p "$proj/app/src/main/java/org/libsdl/app"
cp "$here/android/sdl/"*.java "$proj/app/src/main/java/org/libsdl/app/"
cp "$here/android/Game.java" "$proj/app/src/main/java/com/ageofanything/game/"
cp "$here/android/AndroidManifest.xml" "$proj/app/src/main/AndroidManifest.xml"
sed -i '' 's#<string name="app_name">.*</string>#<string name="app_name">Age of Anything</string>#' "$proj/app/src/main/res/values/strings.xml"
python3 "$here/android/icon.py" "$root" "$proj/app/src/main/res"   # (the game icon as the icon and splash)
sed -i '' 's#^APP_PLATFORM=.*#APP_PLATFORM=android-24#' "$proj/app/jni/Application.mk"
sed -i '' "s#gradle-[0-9.]*-all.zip#gradle-$GRADLE_VERSION-bin.zip#" "$proj/gradle/wrapper/gradle-wrapper.properties"
cat > "$proj/build.gradle" <<EOF
buildscript {
    repositories { google(); mavenCentral() }
    dependencies { classpath 'com.android.tools.build:gradle:$AGP_VERSION' }
}
allprojects { repositories { google(); mavenCentral() } }
EOF
cat > "$proj/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx4g
android.useAndroidX=false
EOF
echo "sdk.dir=$ANDROID_HOME" > "$proj/local.properties"
cat > "$proj/app/build.gradle" <<EOF
apply plugin: 'com.android.application'
android {
    namespace 'com.ageofanything.game'
    compileSdk 35
    ndkVersion '$NDK_VERSION'
    defaultConfig {
        applicationId 'com.ageofanything.game'
        minSdk 24
        targetSdk 35
        versionCode 1
        versionName '0.1'
        externalNativeBuild { ndkBuild { arguments 'APP_PLATFORM=android-24', '-j8'; abiFilters 'arm64-v8a' } }
    }
    externalNativeBuild { ndkBuild { path 'jni/Android.mk' } }
    buildTypes { debug { jniDebuggable false } }
    androidResources { noCompress += ['png', 'json', 'wav', 'ogg', 'glb'] }
    lint { abortOnError false; checkReleaseBuilds false }
}
EOF
# The native build optimised even in a debug APK.
grep -q 'APP_OPTIM' "$proj/app/jni/Application.mk" || echo 'APP_OPTIM := release' >> "$proj/app/jni/Application.mk"

echo "== The game's files"
assets="$proj/app/src/main/assets"
mkdir -p "$assets"
rsync -a "$LOBSTER_SRC/data/" "$assets/data/"                       # Lobster's own: shaders, fonts, controllers
rsync -a --exclude 'later' "$root/data/" "$assets/data/"
rsync -a --exclude '*.import' --exclude '*.uid' "$root/assets/" "$assets/assets/"
rsync -a --exclude '*.import' --exclude '*.uid' "$root/mods/" "$assets/mods/"
rsync -a "$here/textures" "$here/icons" "$assets/"
echo "== Lobster -> C++"
# Folders the game lists come from a table of the APK's folders (apk_files.lobster).
python3 "$here/android/apk_files.py" "$assets" "$stage/apk_files.lobster"
sed -i '' 's#^import std$#import std\
import .apk_files#' "$stage/game.lobster"
sed -i '' 's#let names = scan_folder("data/maps", false)#let names = apk_scan("data/maps")#' "$stage/game.lobster"
sed -E -i '' 's#scan_folder\((here|root|MOD_TEX_DIR), true\)#apk_scan(\1)#' "$stage/gen/mods.lobster"
grep -q 'apk_scan("data/maps")' "$stage/game.lobster"
sed -i '' 's#scan_folder(d + "/bodies", false)#apk_scan(d + "/bodies")#' "$stage/view/voxel.lobster"
grep -q "apk_scan(d" "$stage/view/voxel.lobster"
# A phone's keyboard covers half the screen: the setup page's race box takes it only when tapped, not on opening.
sed -i '' 's#fe_field = if go == "setup": 0 elif go == "lab": 10 else: -1#fe_field = -1#' "$stage/game/lobby.lobster"
grep -q '            fe_field = -1$' "$stage/game/lobby.lobster"
# Fullscreen: in a window the phone's status bar covers the top bar.
sed -i '' 's#^fatal(gl.window("Age of Anything (Lobster)", 1600, 1000, \(.*\) else: 0))$#fatal(gl.window("Age of Anything", 1600, 1000, \1 else: gl.window_init_fullscreen))#' "$stage/game.lobster"
grep -q 'gl.window_init_fullscreen))$' "$stage/game.lobster"
rm -f "$generated"
(cd "$LOBSTER_SRC" && bin/lobster --cpp $LOBSTER_FLAGS "$stage/game.lobster" | grep -v warning || true)
# (SDL3 on Android runs SDL_main from the game's library: the generated main exported under that name)
sed 's/^int main(int argc, char \*argv\[\]) {/extern "C" __attribute__((visibility("default"))) int SDL_main(int argc, char *argv[]) {/' \
	"$generated" > "$out/dev/compiled_lobster/src/compiled_lobster.cpp"
grep -q 'int SDL_main(' "$out/dev/compiled_lobster/src/compiled_lobster.cpp"
rm "$generated"   # (Lobster's tree left as it was)
sed -n 's/^let BAKE_VERSION = \([0-9]*\).*/\1/p' "$here/view/bake_cache.lobster" > "$assets/bake_version"

echo "== The buildings and props, baked once on this machine (src/prebake.sh) and shipped: nothing of them bakes on a phone"
"$here/prebake.sh"
rsync -a --delete "$here/baked/" "$assets/baked/"

echo "== Gradle ($GRADLE_VERSION, offline)"
(cd "$proj" && sh gradlew --offline -q assembleDebug)
cp "$proj/app/build/outputs/apk/debug/app-debug.apk" "$out/age-of-anything.apk"
echo "== $(du -h "$out/age-of-anything.apk" | cut -f1) $out/age-of-anything.apk"
