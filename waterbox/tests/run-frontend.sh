#!/bin/bash
# The window test: the package loaded by Chimera's window (run headless: it
# needs no display), not by its headless runner. The machine is the ZX Spectrum SE, loading the tape the tests
# make. Three things are asked:
#  - the tape run for a number of frames with no button pressed leaves the
#    machine's whole memory byte for byte what the native build leaves (so
#    the machine started on the ROMs built into the core, and the tape
#    loaded);
#  - a setting made in Chimera's configuration reaches the machine: with the
#    tape played as a real one the memory at that frame is another, and is
#    what the native build has with that setting;
#  - the keys the package ships become Chimera's keys.
#
# Usage: waterbox/tests/run-frontend.sh --chimera-root <chimera checkout> [--frames N]
# Needs: Chimera built with its window, the package
# installed (waterbox/build-package.sh -r <chimera>), the native build.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
wb="$(cd "$here/.." && pwd)"
root="$(cd "$wb/.." && pwd)"
frames=300
chimera_root=""
while [ $# -gt 0 ]; do
	case "$1" in
		--chimera-root) chimera_root="$2"; shift ;;
		--frames) frames="$2"; shift ;;
		-*) echo "unknown option: $1" >&2; exit 2 ;;
		*) break ;;
	esac
	shift
done
[ -n "$chimera_root" ] && [ -d "$chimera_root" ] || { echo "say where Chimera is: --chimera-root <chimera checkout>" >&2; exit 2; }
chimera_root="$(cd "$chimera_root" && pwd)"

chimera_exe="$chimera_root/build/meson-linux/source/ui/chimera"
package="$chimera_root/build/Cores/fuse.chimeraCore"
rn="$root/build/meson-native/run-native"
fuse="$root/extern/fuse"
[ -x "$chimera_exe" ] || { echo "Chimera's window is not built: $chimera_exe" >&2; exit 1; }
[ -f "$package" ] || { echo "the package is not installed: $package (run waterbox/build-package.sh -r <chimera>)" >&2; exit 1; }
[ -x "$rn" ] || { echo "the native build is not there: $rn" >&2; exit 1; }

work="$(mktemp -d)"
# the tape the tests load; the SE's ROMs are built into the core, so no
# firmware is set
rom="$work/test.tap"
python3 "$here/make-tape.py" "$rom" || exit 1
firmware="{}"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

# Chimera's window, run headless: the cores installed in the checkout, its
# settings, cache and recovery files the run's own, and nothing carried over
# from a Chimera installed on this machine
export ALSOFT_DRIVERS=null CHIMERA_CORES_DIR="$chimera_root/build/Cores" CHIMERA_QT_CACHE="$work/qt-cache" CHIMERA_QT_RECOVERY="$work/qt-recovery" \
	CHIMERA_QT_HASHES="$work/qt-file-hashes.txt" CHIMERA_QT_CHIMERA_SETTINGS="$work/no-chimera-config.ini"

ok=0
failed=0
report() { printf '%-22s %-6s %s\n' "$1" "$2" "$3"; case "$2" in PASS) ok=$((ok + 1)) ;; *) failed=$((failed + 1)) ;; esac; }

run_frontend() { # <tag> <configuration> <frames>
	local tag="$1" cfg="$2" nframes="$3"
	local job="$work/job.$tag.txt"
	local out="$work/$tag.ram.bin"
	[ "${lua_script:-}" = dump-controls.lua ] && out="$work/$tag.controls.json"
	{
		echo "frames=$nframes"
		echo "out=$out"
		echo "meta=$work/$tag.meta.txt"
		echo "shot="
	} > "$job"
	local project
	project="$(game_project "$tag" "$cfg" "$package" "$rom")" || { echo "no project made (see tests/work/project.$tag/make.log)" > "$work/$tag.log"; return 1; }
	( cd "$chimera_root" && MINIHAWK_JOB="$job" timeout 900 "$chimera_exe" --headless \
		"--config=$cfg" "--core=$package" "--lua=$here/${lua_script:-frontend-ram.lua}" "--project=$project" ) > "$work/$tag.log" 2>&1
	[ -f "$work/$tag.meta.txt" ] && grep -q "^status=OK" "$work/$tag.meta.txt"
}
native_ram() { # <tag> <options...>
	local tag="$1"; shift
	"$rn" "$rom" "$work/native-dir.$tag" --set machine=se --frames "$frames" --dump-ram "$work/native.$tag.ram.bin" "$@" > "$work/native.$tag.txt" 2>&1
}
# A game runs only in a project (Chimera, 2026-10-26): each run opens one made
# of its game with chimera-run --new-project, holding the settings (and the firmware)
# settings_config was given for the config it runs with.
declare -A settings_of firmware_of
settings_config() { python3 "$here/settings-config.py" "$1" "$2" "$firmware"; settings_of["$1"]="$2"; firmware_of["$1"]="$firmware"; }
crun="$chimera_root/build/dll/chimera-run"
game_project() { # tag, config, package, game: prints the project's path
	local dir="$work/project.$1" settings="${settings_of[$2]:-}" firmware="${firmware_of[$2]:-}"
	local pkg="$3" game="$4"
	local fw=()
	[ -n "$firmware" ] && mapfile -t fw < <(python3 -c 'import json,sys
for k, v in json.loads(sys.argv[1]).items(): print("--firmware"); print(k + "=" + v)' "$firmware")
	rm -rf "$dir" && mkdir -p "$dir" && cp "$game" "$dir/"
	"$crun" --new-project "$dir/$1.chimeraProject" "$pkg" "$dir/$(basename "$game")" \
		--settings "${settings:-"{}"}" "${fw[@]}" > "$dir/make.log" 2>&1 && echo "$dir/$1.chimeraProject"
}

settings_config "$work/settings.base.json" '{"machine": "se"}'
if ! native_ram base; then
	report "window:memory" FAIL "the native runner failed: $(tail -1 "$work/native.base.txt")"
elif ! run_frontend base "$work/settings.base.json" "$frames"; then
	report "window:memory" FAIL "Chimera did not finish the run: $(grep '^detail=' "$work/base.meta.txt" 2>/dev/null) $(tail -2 "$work/base.log" | tr '\n' ' ' | cut -c1-200)"
elif cmp -s "$work/native.base.ram.bin" "$work/base.ram.bin"; then
	report "window:memory" PASS "the tape loaded and run for $frames frames in Chimera's window, on the SE: the machine's memory ($(wc -c < "$work/base.ram.bin") bytes) is the native build's"
else
	report "window:memory" FAIL "the memory differs from the native build's"
fi

settings_config "$work/settings.real.json" '{"machine": "se", "tape_loading": "real"}'
if ! native_ram real --set tape_loading=real; then
	report "window:setting" FAIL "the native runner failed: $(tail -1 "$work/native.real.txt")"
elif ! run_frontend real "$work/settings.real.json" "$frames"; then
	report "window:setting" FAIL "Chimera did not finish the run: $(tail -2 "$work/real.log" | tr '\n' ' ' | cut -c1-200)"
elif cmp -s "$work/native.real.ram.bin" "$work/real.ram.bin" && ! cmp -s "$work/real.ram.bin" "$work/base.ram.bin"; then
	report "window:setting" PASS "with Tape Loading set to real in the project's settings the memory at frame $frames is another, and is the native build's with that setting"
else
	report "window:setting" FAIL "real tape: same as native $(cmp -s "$work/native.real.ram.bin" "$work/real.ram.bin" && echo yes || echo no); differs from the fast tape $(cmp -s "$work/real.ram.bin" "$work/base.ram.bin" && echo no || echo yes)"
fi

# the keys the package ships are the machine's when nobody changed them (the
# window keeps only the keys a person changed; fresh settings have none)
lua_script=dump-controls.lua
cp "$work/settings.base.json" "$work/settings.keys.json"
settings_of["$work/settings.keys.json"]="${settings_of[$work/settings.base.json]}"
firmware_of["$work/settings.keys.json"]="${firmware_of[$work/settings.base.json]}"
if run_frontend keys "$work/settings.keys.json" 1; then
	lua_script=
	if python3 "$here/check-keybinds.py" "$work/keys.controls.json" "$wb/default_keybinds.json" "ZX Spectrum Keyboard and Joysticks" > "$work/keys.txt" 2>&1; then
		report "window:keys" PASS "$(cat "$work/keys.txt")"
	else
		report "window:keys" FAIL "$(head -1 "$work/keys.txt")"
	fi
else
	report "window:keys" FAIL "Chimera did not finish the run: $(tail -2 "$work/keys.log" | tr '\n' ' ' | cut -c1-200)"
fi

echo
echo "$ok ok, $failed failed"
[ "$failed" -eq 0 ]
