#!/bin/sh
# The core's tests. Each line says what was compared. The script ends with a
# count of tests that passed, failed and were skipped, and with an error if
# any failed. A skipped test is not a pass.
#
#   waterbox/run-gate.sh
#
# CHIMERA_ROOT=<a Chimera checkout> adds the tests that run the package in
# Chimera's own headless runner (see them below).
# FUSE_TEST_ROMS=<folder> says where the machines' ROM files are (48.rom and
# the rest, by Fuse's names). Without it, tests/roms-local is looked in.
# FUSE_TEST_GAME=<a tape> names the game for the one test that plays a game;
# without it, tests/games-local/Manic Miner (Software Projects).tzx.
#
# Needs the native build (meson setup build/meson-native ... && ninja) and the
# sandboxed core (waterbox/setup-guest.sh && ninja -C build/meson-guest).
#
# WHAT RUNS WITH NO ROMS OF YOURS. A Spectrum needs its ROM, and the
# Spectrum's ROMs are Amstrad's: this repository has none. One machine Fuse
# emulates, the ZX Spectrum SE, runs on OpenSE BASIC, which is free software
# (GNU GPL) and comes with Fuse; the tests read its two ROMs from the pinned
# Fuse submodule. So every test below runs on the SE everywhere, a CI runner
# included, with a tape this script makes itself. The other fifteen machines
# are tested where their ROMs are, and are named as skipped where they are
# not.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
native="$root/build/meson-native/run-native"
runwbx="$root/build/meson-native/run-wbx"
coretest="$root/build/meson-native/z80-coretest"
core="$root/build/meson-guest/core.wbx"
fuse="$root/extern/fuse"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
ok=0; failed=0; skipped=0
report() { # <test> <PASS|FAIL|SKIP> <what>
	printf '%-22s %-6s %s\n' "$1" "$2" "$3"
	case "$2" in PASS) ok=$((ok + 1)) ;; FAIL) failed=$((failed + 1)) ;; *) skipped=$((skipped + 1)) ;; esac
}
# what a run ended with, without the word that says how it got there
last() { tail -1 "$1" 2> /dev/null | cut -d' ' -f2-; }
field() { # <file> <name>: the value of name= in the file's last line
	tail -1 "$1" 2> /dev/null | tr ' ' '\n' | sed -n "s/^$2=//p"
}
# (a shell function's variables are the script's: these have names of their
# own, or they would overwrite the loops' below)
run_n=0
nat() { # <name> <program or -> <options...>: a native run, its lines in $work/<name>.out
	run_name="$1"; run_prog="$2"; shift 2
	run_n=$((run_n + 1))
	"$native" "$run_prog" "$work/dir-$run_n" "$@" > "$work/$run_name.out" 2> "$work/$run_name.err"
}
box() { # <name> <program or -> <options...>: the same in the sandbox
	run_name="$1"; run_prog="$2"; shift 2
	"$runwbx" "$core" "$run_prog" "$@" > "$work/$run_name.out" 2> "$work/$run_name.err"
}

if [ ! -x "$native" ] || [ ! -x "$runwbx" ] || [ ! -f "$core" ] || [ ! -x "$coretest" ]; then
	echo "not built: this needs build/meson-native/run-native, run-wbx and z80-coretest, and build/meson-guest/core.wbx (docs/BUILDING.md)" >&2
	exit 2
fi
if [ ! -f "$fuse/roms/se-0.rom" ] || [ ! -f "$fuse/z80/tests/tests.in" ]; then
	echo "extern/fuse is not checked out: git submodule update --init" >&2
	exit 2
fi

# The ROMs. The SE's two, from Fuse, in a folder of their own: the tests hand
# a runner a folder, and must not hand it Fuse's whole roms/ directory.
se_roms="$work/se-roms"
mkdir "$se_roms"
cp "$fuse/roms/se-0.rom" "$fuse/roms/se-1.rom" "$se_roms/"
roms="${FUSE_TEST_ROMS:-$root/tests/roms-local}"
have() { # <rom>...: whether the folder of ROMs has them all
	for rom_file in "$@"; do [ -f "$roms/$rom_file" ] || return 1; done
}
# the tape every test loads: a BASIC program that starts by itself, paints
# the screen, and prints the keys and the Kempston joystick it sees
tape="$work/test.tap"
python3 "$here/tests/make-tape.py" "$tape" || exit 2

# Buttons, as the runners' --press takes them (hex, bit 0 the first button
# the package declares): the key Q, the key 0, and the first joystick's Fire.
key_q=400; key_0=200; joy_fire=800000000000

# Fuse's own test of its Z80: 1355 cases through the processor alone, the
# output compared with the file Fuse keeps. No ROM is involved.
"$coretest" "$fuse/z80/tests/tests.in" > "$work/coretest.out" 2> "$work/coretest.err"
cases="$(grep -c '^$' "$fuse/z80/tests/tests.in")"
if [ -s "$work/coretest.out" ] && cmp -s "$work/coretest.out" "$fuse/z80/tests/tests.expected" && [ "$cases" -gt 1000 ]; then
	report "upstream:z80" PASS "Fuse's own test of its Z80, $cases cases: the output is the file Fuse expects ($(wc -c < "$work/coretest.out") bytes)"
else
	report "upstream:z80" FAIL "the output differs from z80/tests/tests.expected: $(cmp "$work/coretest.out" "$fuse/z80/tests/tests.expected" 2>&1 | head -1)"
fi

# Fuse's own unit tests (fuse --unittests): the machine's memory paging,
# timing, keyboard, sound filters, and opening every kind of file. They
# switch through every machine, so they need every machine's ROM, and they
# write scratch files, so they are run natively.
every="48.rom 128-0.rom 128-1.rom plus2-0.rom plus2-1.rom plus3-0.rom plus3-1.rom plus3-2.rom plus3-3.rom plus3e-0.rom plus3e-1.rom plus3e-2.rom plus3e-3.rom tc2048.rom tc2068-0.rom tc2068-1.rom 128p-0.rom 128p-1.rom trdos.rom gluck.rom 256s-0.rom 256s-1.rom 256s-2.rom 256s-3.rom se-0.rom se-1.rom"
# shellcheck disable=SC2086
if ! have $every; then
	report "upstream:unittests" SKIP "needs every machine's ROM in FUSE_TEST_ROMS or tests/roms-local (26 files; docs/BUILDING.md lists them)"
else
	nat unit - --roms "$roms" --unittests --fixtures "$fuse/lib/tests"
	if grep -q "^unittests failed=0$" "$work/unit.out" && grep -q "Final return value: 0" "$work/unit.err" "$work/unit.out"; then
		report "upstream:unittests" PASS "Fuse's own unit tests, run natively on the core's build of Fuse: none failed"
	else
		report "upstream:unittests" FAIL "$(grep -h 'failed\|Final return' "$work/unit.out" "$work/unit.err" | tail -3 | tr '\n' ' ' | cut -c1-200)"
	fi
fi

# The machines: name | the "machine" setting | the ROMs it needs | frames a
# second as the core must say them | the picture's size.
machines="
se|se|se-0.rom se-1.rom|3500000/69888|640x480
16|16|48.rom|3500000/69888|320x240
48|48|48.rom|3500000/69888|320x240
48_ntsc|48_ntsc|48.rom|3527500/59136|320x240
128|128|128-0.rom 128-1.rom|3546900/70908|320x240
plus2|plus2|plus2-0.rom plus2-1.rom|3546900/70908|320x240
plus2a|plus2a|plus3-0.rom plus3-1.rom plus3-2.rom plus3-3.rom|3546900/70908|320x240
plus3|plus3|plus3-0.rom plus3-1.rom plus3-2.rom plus3-3.rom|3546900/70908|320x240
plus3e|plus3e|plus3e-0.rom plus3e-1.rom plus3e-2.rom plus3e-3.rom|3546900/70908|320x240
2048|2048|tc2048.rom|3500000/69888|640x480
2068|2068|tc2068-0.rom tc2068-1.rom|3500000/69888|640x480
ts2068|ts2068|tc2068-0.rom tc2068-1.rom|3528000/58688|640x480
pentagon|pentagon|128p-0.rom 128p-1.rom trdos.rom|3584000/71680|320x240
pentagon512|pentagon512|128p-0.rom 128p-1.rom trdos.rom gluck.rom|3584000/71680|320x240
pentagon1024|pentagon1024|128p-0.rom 128p-1.rom trdos.rom gluck.rom|3584000/71680|320x240
scorpion|scorpion|256s-0.rom 256s-1.rom 256s-2.rom 256s-3.rom|3500000/69888|320x240
"
frames=600
old_ifs="$IFS"
# which folder a machine's ROMs come from: the SE's own, or the user's
roms_for() { [ "$1" = se ] && echo "$se_roms" || echo "$roms"; }

# The sandboxed core is the native build: for every machine, switched on with
# nothing in it and buttons pressed by a fixed pattern, the same line at every
# sixtieth frame - where the processor is, the machine's memory, its sound,
# its picture and every picture on the way. And each is the machine it was
# asked to be, at its own frame rate and picture size.
bad=""; ran=""; missing=""
for line in $(printf '%s\n' "$machines" | grep '|' | tr ' ' '^'); do
	IFS='|'; set -- $(printf '%s' "$line" | tr '^' ' '); IFS="$old_ifs"
	m_name="$1"; m_set="$2"; m_roms="$3"; m_fps="$4"; m_size="$5"
	# shellcheck disable=SC2086
	if [ "$m_name" != se ] && ! have $m_roms; then
		missing="$missing $m_name"
		continue
	fi
	from="$(roms_for "$m_name")"
	nat "n-$m_name" - --roms "$from" --set "machine=$m_set" --frames "$frames" --every 60 --exercise
	box "s-$m_name" - --roms "$from" --set "machine=$m_set" --frames "$frames" --every 60 --exercise
	ran="$ran $m_name"
	if ! [ -s "$work/n-$m_name.out" ] || ! cmp -s "$work/n-$m_name.out" "$work/s-$m_name.out"; then
		bad="$bad $m_name(native and sandbox differ: $(last "$work/s-$m_name.out" | cut -c1-70) $(tail -1 "$work/s-$m_name.err" | cut -c1-90))"
	elif [ "$(head -1 "$work/s-$m_name.out")" != "machine=$m_set framesPerSecond=$m_fps" ]; then
		bad="$bad $m_name(it says [$(head -1 "$work/s-$m_name.out")], not machine=$m_set framesPerSecond=$m_fps)"
	elif [ "$(field "$work/s-$m_name.out" video)" != "$m_size" ]; then
		bad="$bad $m_name(picture $(field "$work/s-$m_name.out" video), not $m_size)"
	elif [ "$(field "$work/s-$m_name.out" inputFrames)" -le 0 ] 2> /dev/null; then
		bad="$bad $m_name(it never looked at its keyboard)"
	fi
done
count="$(echo $ran | wc -w)"
without=""
[ -n "$missing" ] && without="; NOT RUN for want of their ROMs:$missing"
if [ -z "$bad" ]; then
	report "machines:sandbox" PASS "$count machines ($(echo $ran | tr ' ' ',')), $frames frames each with buttons pressed: the sandbox gives the native build's lines, and each is the machine, frame rate and picture size it should be$without"
else
	report "machines:sandbox" FAIL "$bad"
fi

# A state is the whole machine: saved and loaded before every frame, the run
# is the run that was never stopped. For every machine that ran above.
bad=""
for m_name in $ran; do
	from="$(roms_for "$m_name")"
	box "r-$m_name" - --roms "$from" --set "machine=$m_name" --frames "$frames" --every 60 --exercise --rerecord
	cmp -s "$work/s-$m_name.out" "$work/r-$m_name.out" || bad="$bad $m_name($(last "$work/r-$m_name.out" | cut -c1-70) $(tail -1 "$work/r-$m_name.err" | cut -c1-90))"
done
if [ -z "$bad" ]; then
	report "state:every-frame" PASS "$count machines: a state saved and loaded before each of $frames frames changes nothing$without"
else
	report "state:every-frame" FAIL "$bad"
fi

# A tape loads, both ways. "fast" answers the ROM's loading routine at once;
# "real" plays the tape as a tape recorder would, which for this small tape
# is about fifteen seconds. Both must end with the same program running and
# the same screen - and it is not the screen of a machine with no tape. The
# sandbox must do what the native build does, at every sixtieth frame of
# both. On the SE, and on the 48K and 128K Spectrums where their ROMs are.
bad=""; taped=""
for m_name in se 48 128; do
	echo " $ran " | grep -q " $m_name " || continue
	from="$(roms_for "$m_name")"
	nat "tf-$m_name" "$tape" --roms "$from" --set "machine=$m_name" --frames 1500 --every 60
	box "tfs-$m_name" "$tape" --roms "$from" --set "machine=$m_name" --frames 1500 --every 60
	nat "tr-$m_name" "$tape" --roms "$from" --set "machine=$m_name" --set tape_loading=real --frames 1500 --every 60
	box "trs-$m_name" "$tape" --roms "$from" --set "machine=$m_name" --set tape_loading=real --frames 1500 --every 60
	box "tn-$m_name" - --roms "$from" --set "machine=$m_name" --frames 1500
	taped="$taped $m_name"
	fast_at="$(grep -n "videoHash=$(field "$work/tfs-$m_name.out" videoHash) " "$work/tfs-$m_name.out" | head -1 | cut -d: -f1)"
	real_at="$(grep -n "videoHash=$(field "$work/tfs-$m_name.out" videoHash) " "$work/trs-$m_name.out" | head -1 | cut -d: -f1)"
	if ! cmp -s "$work/tf-$m_name.out" "$work/tfs-$m_name.out" || ! cmp -s "$work/tr-$m_name.out" "$work/trs-$m_name.out"; then
		bad="$bad $m_name(native and sandbox differ)"
	elif [ "$(field "$work/tfs-$m_name.out" videoHash)" != "$(field "$work/trs-$m_name.out" videoHash)" ]; then
		bad="$bad $m_name(fast and real end with different screens)"
	elif [ "$(field "$work/tfs-$m_name.out" videoHash)" = "$(field "$work/tn-$m_name.out" videoHash)" ]; then
		bad="$bad $m_name(the screen is the screen of a machine with no tape)"
	elif [ -z "$fast_at" ] || [ -z "$real_at" ] || [ "$real_at" -le "$fast_at" ]; then
		bad="$bad $m_name(the real tape was not slower: its screen came at line ${real_at:-none}, the fast one's at line ${fast_at:-none})"
	fi
done
if [ -z "$bad" ]; then
	report "tape:loading" PASS "a tape made by this script loads on$taped, fast and as a real tape plays (which gets there later), and both end with the same screen; the sandbox prints the native build's lines"
else
	report "tape:loading" FAIL "$bad"
fi

# The buttons reach the machine. The tape's program prints the keys it sees
# and what a Kempston joystick says. So: a key pressed makes another screen
# than no key; the joystick's Fire makes another again when the joystick is
# a Kempston one, the same screen as the key 0 when it is a Sinclair one
# (whose fire button IS the key 0), and nothing when no joystick is plugged
# in. The same natively and in the sandbox. And the program looked at the
# keyboard in some frames and not in others, which is what the frontend's lag
# counter is made of.
se_run() { # <name> <options...>
	se_name="$1"; shift
	box "$se_name" "$tape" --roms "$se_roms" --set machine=se --frames 500 "$@"
}
se_run in-none
se_run in-key --press "300:40:$key_q"
se_run in-kemp --press "300:40:$joy_fire"
se_run in-sinc --set joystick_1=sinclair1 --press "300:40:$joy_fire"
se_run in-zero --set joystick_1=sinclair1 --press "300:40:$key_0"
se_run in-nojoy --set joystick_1=none --press "300:40:$joy_fire"
se_run in-nojoy-none --set joystick_1=none
nat in-key-n "$tape" --roms "$se_roms" --set machine=se --frames 500 --press "300:40:$key_q"
nat in-kemp-n "$tape" --roms "$se_roms" --set machine=se --frames 500 --press "300:40:$joy_fire"
vh() { field "$work/$1.out" videoHash; }
asked="$(field "$work/in-none.out" inputFrames)"
why=""
[ -n "$(vh in-none)" ] || why="$why the run printed nothing;"
[ "$(vh in-key)" != "$(vh in-none)" ] || why="$why a key changes nothing;"
[ "$(vh in-kemp)" != "$(vh in-none)" ] && [ "$(vh in-kemp)" != "$(vh in-key)" ] || why="$why the Kempston fire button changes nothing;"
[ "$(vh in-sinc)" = "$(vh in-zero)" ] && [ "$(vh in-sinc)" != "$(vh in-kemp)" ] || why="$why a Sinclair joystick's fire is not the key 0;"
[ "$(vh in-nojoy)" = "$(vh in-nojoy-none)" ] || why="$why an unplugged joystick's button did something;"
cmp -s "$work/in-key.out" "$work/in-key-n.out" && cmp -s "$work/in-kemp.out" "$work/in-kemp-n.out" || why="$why native and sandbox differ;"
[ "${asked:-0}" -gt 0 ] && [ "${asked:-0}" -lt 500 ] || why="$why the keyboard was looked at in ${asked:-no} of 500 frames;"
if [ -z "$why" ]; then
	report "input:buttons" PASS "a key, a Kempston joystick and a Sinclair joystick each reach the program (the Sinclair one as the key 0), an unplugged joystick does nothing, the same natively; the keyboard was looked at in $asked of 500 frames"
else
	report "input:buttons" FAIL "$why"
fi

# The tape's buttons and Reset. With the tape played as a real one and the
# setting that lets the tape start by itself turned off, the tape is the
# buttons' alone: untouched, it never loads; Play pressed, it loads; Play
# and then Stop before it is through, it does not. With the setting on (as
# it comes) the tape loads with no button at all - that is tape:loading
# above. Reset pressed when the program runs brings back the machine's
# first screen.
se_run tp-never --set tape_loading=real --set tape_auto=false --frames 1700
se_run tp-play --set tape_loading=real --set tape_auto=false --frames 1700 --press 300:5:10000000000
se_run tp-stop --set tape_loading=real --set tape_auto=false --frames 1700 --press 300:5:10000000000 --press 500:5:20000000000
se_run tp-reset --frames 900 --press 400:5:40000000000
se_run tp-plain --frames 1500
box tp-boot - --roms "$se_roms" --set machine=se --frames 500
why=""
[ "$(vh tp-never)" != "$(vh tp-plain)" ] || why="$why the tape loaded with nobody pressing Play;"
[ "$(vh tp-play)" = "$(vh tp-plain)" ] || why="$why Play did not load the tape;"
[ "$(vh tp-stop)" != "$(vh tp-plain)" ] || why="$why Stop did not stop the tape;"
[ "$(vh tp-reset)" = "$(vh tp-boot)" ] || why="$why Reset did not bring back the first screen;"
if [ -z "$why" ]; then
	report "input:tape-and-reset" PASS "with the tape left to the buttons: untouched it never loads, Play loads it, Stop half way leaves it unloaded; and Reset brings back the machine's first screen"
else
	report "input:tape-and-reset" FAIL "$why"
fi

# Saved by one process half way and loaded by another, a run ends where the
# unbroken run ends: the tape's program, with a key held across the save.
box so-whole "$tape" --roms "$se_roms" --set machine=se --frames 600 --every 60 --press "280:60:$key_q"
box so-half "$tape" --roms "$se_roms" --set machine=se --frames 600 --every 60 --press "280:60:$key_q" --save-state "$work/se.state" --at 300
box so-rest "$tape" --roms "$se_roms" --set machine=se --frames 600 --every 60 --press "280:60:$key_q" --state "$work/se.state"
if [ -s "$work/se.state" ] && [ -n "$(tail -1 "$work/so-whole.out")" ] && [ "$(tail -1 "$work/so-rest.out")" = "$(tail -1 "$work/so-whole.out")" ]; then
	report "state:other-process" PASS "saved after frame 300 with a key held and loaded by another process, the run ends where the unbroken run ends ($(wc -c < "$work/se.state") bytes)"
else
	report "state:other-process" FAIL "unbroken [$(last "$work/so-whole.out" | cut -c1-80)] carried on [$(last "$work/so-rest.out" | cut -c1-80)]"
fi

# A snapshot file is a whole machine. Fuse writes one of the machine after
# the tape's program has run (natively: a core writes no files), and a
# machine started from that file shows that program's screen from its first
# frames, natively and in the sandbox alike. On the SE in Fuse's own format
# (.szx), the only one that can describe that machine; and where 48.rom is,
# on a 48K Spectrum in the two old formats most snapshots are in (.z80 and
# .sna) - there with the settings asking for a 128K machine, because a
# snapshot says which machine it is of and that must win.
bad=""; snapped=""
snap_test() { # <format> <machine> <folder of ROMs> <machine the settings ask for when loading>
	nat "sw-$1" "$tape" --roms "$3" --set "machine=$2" --frames 400 --write-snapshot "$work/made.$1"
	nat "sl-$1" "$work/made.$1" --roms "$3" --set "machine=$4" --frames 50 --every 10
	box "sls-$1" "$work/made.$1" --roms "$3" --set "machine=$4" --frames 50 --every 10
	snapped="$snapped .$1"
	[ -s "$work/made.$1" ] || { bad="$bad $1(no snapshot was written: $(tail -1 "$work/sw-$1.err" | cut -c1-80))"; return; }
	cmp -s "$work/sl-$1.out" "$work/sls-$1.out" || bad="$bad $1(native and sandbox differ)"
	[ "$(head -1 "$work/sls-$1.out" | cut -d' ' -f1)" = "machine=$2" ] || bad="$bad $1(it starts as [$(head -1 "$work/sls-$1.out")], not as the $2 it was taken on)"
	if [ "$1" = sna ]; then
		# A .sna file does not say what is plugged into the machine, and for
		# its first two frames the joystick port reads 15, which the tape's
		# program prints: the screen is the program's, with "1515" added.
		# So for this format: the program is running (not the screen of a
		# machine just switched on), and that is all.
		[ "$(vh "sls-$1")" != "$(vh tn-48)" ] || bad="$bad $1(the screen is the screen of a machine just switched on)"
	else
		[ "$(vh "sls-$1")" = "$(vh "sw-$1")" ] || bad="$bad $1(the snapshot's screen is not the screen it was taken of)"
	fi
}
snap_test szx se "$se_roms" se
if have 48.rom 128-0.rom 128-1.rom; then
	snap_test z80 48 "$roms" 128
	snap_test sna 48 "$roms" 128
	old_formats=""
else
	old_formats="; .z80 and .sna NOT RUN for want of 48.rom, 128-0.rom and 128-1.rom"
fi
if [ -z "$bad" ]; then
	report "snapshot:load" PASS "a snapshot that Fuse wrote of the running program ($snapped ) starts as the machine it was taken on, with that program's screen, the same natively and in the sandbox$old_formats"
else
	report "snapshot:load" FAIL "$bad"
fi

# What cannot be run is refused with a reason: a machine that does not
# exist, a machine whose ROM is not there, a file that is nothing Fuse knows.
box x-machine - --roms "$se_roms" --set machine=zx81 --frames 5
box x-norom - --roms "$se_roms" --set machine=48 --frames 5
printf 'this is not a tape' > "$work/nothing.tap"
box x-file "$work/nothing.tap" --roms "$se_roms" --set machine=se --frames 5
why=""
grep -q "no such machine: zx81" "$work/x-machine.err" || why="$why an unknown machine is not refused [$(tail -1 "$work/x-machine.err" | cut -c1-60)];"
grep -q "couldn't find ROM '48.rom'" "$work/x-norom.err" || why="$why a missing ROM is not named [$(tail -1 "$work/x-norom.err" | cut -c1-60)];"
grep -q "^Init: " "$work/x-file.err" || why="$why a file that is no tape is not refused [$(tail -1 "$work/x-file.out" | cut -c1-60)];"
if [ -z "$why" ]; then
	report "settings:refused" PASS "an unknown machine, a machine whose ROM is missing (the ROM is named) and a file that is nothing Fuse knows are each refused with a reason: $(sed -n 's/^Init: //p' "$work/x-file.err" | head -1 | cut -c1-70)"
else
	report "settings:refused" FAIL "$why"
fi

# A game, where there is one: this repository has none and may have none.
# Manic Miner (Software Projects, 1983) from its tape, on a 48K Spectrum:
# loaded, ENTER pressed at the title, and Willy walked and jumped for a
# while. The sandbox must give the native build's lines, the game must have
# been played (the picture after the keys is not the picture without them),
# and a state before every frame must change nothing.
game="${FUSE_TEST_GAME:-$root/tests/games-local/Manic Miner (Software Projects).tzx}"
if [ ! -f "$game" ]; then
	report "game:manic-miner" SKIP "needs the game's tape: FUSE_TEST_GAME=<Manic Miner .tzx>, or tests/games-local/Manic Miner (Software Projects).tzx"
elif ! have 48.rom; then
	report "game:manic-miner" SKIP "needs 48.rom in FUSE_TEST_ROMS or tests/roms-local"
else
	# ENTER at frame 1600; then right (P), a jump (SPACE), left (O), right
	play="--press 1600:10:20000000 --press 1700:120:80000 --press 1760:10:8000000000 --press 1900:60:40000 --press 2000:150:80000 --press 2060:10:8000000000"
	# shellcheck disable=SC2086
	nat g-n "$game" --roms "$roms" --frames 2400 --every 100 $play
	# shellcheck disable=SC2086
	box g-s "$game" --roms "$roms" --frames 2400 --every 100 $play
	# shellcheck disable=SC2086
	box g-r "$game" --roms "$roms" --frames 2400 --every 100 $play --rerecord
	box g-idle "$game" --roms "$roms" --frames 2400 --every 100
	if [ -s "$work/g-n.out" ] && cmp -s "$work/g-n.out" "$work/g-s.out" && cmp -s "$work/g-s.out" "$work/g-r.out" && ! cmp -s "$work/g-s.out" "$work/g-idle.out"; then
		report "game:manic-miner" PASS "Manic Miner loaded from its tape and played for 800 frames: the sandbox prints the native build's lines, a state before every frame changes nothing, and it is not the run with no keys: $(last "$work/g-s.out" | cut -c1-90)"
	else
		report "game:manic-miner" FAIL "native [$(last "$work/g-n.out" | cut -c1-70)] sandbox [$(last "$work/g-s.out" | cut -c1-70)] with states [$(last "$work/g-r.out" | cut -c1-70)]"
	fi
fi

# The package in the frontend's own engine (chimera-run, from a Chimera
# checkout named by CHIMERA_ROOT that has the package installed by
# waterbox/build-package.sh), on the SE with the tape:
#  - a movie with keys, recorded there and played back by another process,
#    shows at a frame the picture this repository's own runner has there;
#  - the same movie with the engine's own save and load before every frame
#    shows the same picture;
#  - a movie's row has the columns the package declares, and the movie
#    recorded is the movie that was played;
#  - with a ROM not handed over the package refuses to start and names it.
chimera_root="${CHIMERA_ROOT:-}"
engine="$chimera_root/build/meson-linux/chimera-run"
package="$chimera_root/build/Cores/fuse.chimeraCore"
same="$here/tests/same-picture.py"
if [ -z "$chimera_root" ] || [ ! -x "$engine" ] || [ ! -f "$package" ]; then
	why="set CHIMERA_ROOT to a Chimera checkout with build/meson-linux/chimera-run and the package (waterbox/build-package.sh -r <it>)"
	report "frontend:picture" SKIP "$why"
	report "frontend:states" SKIP "$why"
	report "frontend:movie" SKIP "$why"
	report "frontend:firmware" SKIP "$why"
else
	fe_frames=500
	shot=480
	se_set='{"machine":"se"}'
	fw="--firmware se-0.rom=$se_roms/se-0.rom --firmware se-1.rom=$se_roms/se-1.rom"
	python3 "$here/tests/make-movie.py" "$fe_frames" > "$work/keys.movie"
	# shellcheck disable=SC2086
	env -u DISPLAY "$engine" "$package" "$tape" "$work/keys.movie" --record "$work/fe.movie" --settings "$se_set" $fw --screenshot "$shot=$work/fe-a.tga" > "$work/fe-record.out" 2>&1
	# shellcheck disable=SC2086
	env -u DISPLAY "$engine" "$package" "$tape" "$work/fe.movie" --settings "$se_set" $fw --screenshot "$shot=$work/fe.tga" > "$work/fe-play.out" 2>&1
	played=$?
	# the engine counts frames from 0, the runner from 1; the same keys
	# shellcheck disable=SC2046
	box fe "$tape" --roms "$se_roms" --set machine=se --frames $((shot + 1)) --ppm "$work/fe.ppm" $(python3 "$here/tests/make-movie.py" "$fe_frames" --as-presses)
	verdict="$(python3 "$same" "$work/fe.tga" "$work/fe.ppm" 2>&1)"; same_rc=$?
	if [ "$played" = 0 ] && grep -q "^frames=$fe_frames" "$work/fe-play.out" && [ "$same_rc" = 0 ] && cmp -s "$work/fe-a.tga" "$work/fe.tga"; then
		report "frontend:picture" PASS "a movie of $fe_frames frames with keys and a joystick, recorded in chimera-run and played back by another process: its picture at frame $shot is this repository's runner's ($verdict)"
	else
		report "frontend:picture" FAIL "chimera-run exit $played; pictures: $verdict; $(tail -1 "$work/fe-play.out")"
	fi
	# shellcheck disable=SC2086
	env -u DISPLAY "$engine" "$package" "$tape" "$work/fe.movie" --settings "$se_set" $fw --rerecord --screenshot "$shot=$work/fe-states.tga" > "$work/fe-states.out" 2>&1
	stated=$?
	verdict="$(python3 "$same" "$work/fe-states.tga" "$work/fe.ppm" 2>&1)"; same_rc=$?
	if [ "$stated" = 0 ] && [ "$same_rc" = 0 ]; then
		report "frontend:states" PASS "the same movie with the engine's save and load before every frame: the same picture at frame $shot ($verdict)"
	else
		report "frontend:states" FAIL "chimera-run --rerecord exit $stated; pictures: $verdict; $(tail -1 "$work/fe-states.out")"
	fi
	row="$(grep -m1 '^|' "$work/fe.movie" | tr -d '\r')"
	held="$(grep -c '[0-9A-Za-z<^$_>#%]' "$work/fe.movie")"
	if [ "$(printf '%s' "$row" | tr -cd '|' | wc -c)" = 4 ] && [ "${#row}" = 57 ] && [ "$held" -gt 0 ] && cmp -s "$work/keys.movie" "$work/fe.movie"; then
		report "frontend:movie" PASS "a recorded movie's row has 43 columns for the keyboard, the tape and Reset and 5 for each joystick, and the movie recorded is the movie that was played ($held rows with a button held)"
	else
		report "frontend:movie" FAIL "a row is [$row] (${#row} characters); $held rows with a button; recorded $(wc -l < "$work/fe.movie") rows of $(wc -l < "$work/keys.movie")"
	fi
	env -u DISPLAY "$engine" "$package" "$tape" "$work/keys.movie" --settings "$se_set" --firmware "se-0.rom=$se_roms/se-0.rom" > "$work/fe-nofw.out" 2>&1
	refused=$?
	if [ "$refused" != 0 ] && grep -q "se-1.rom" "$work/fe-nofw.out"; then
		report "frontend:firmware" PASS "with one of the machine's two ROMs not handed over the package does not start, and the missing ROM is named (exit $refused)"
	else
		report "frontend:firmware" FAIL "exit $refused: $(tail -1 "$work/fe-nofw.out" | cut -c1-120)"
	fi
fi

echo
echo "$ok ok, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
