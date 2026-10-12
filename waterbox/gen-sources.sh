#!/bin/sh
# Writes the source files Fuse and libspectrum make while they build, into a
# directory of the build's own. Upstream makes them with Perl scripts (and
# with flex and bison for the debugger's command language) from make rules;
# this runs the same scripts with the same arguments, without configure or
# make. Nothing under extern/ is written.
#
#   waterbox/gen-sources.sh <output directory>
#
# Needs: perl, flex, bison, and a C compiler for the host (CC, or cc).
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
out="$1"
fuse="$root/extern/fuse"
ls="$root/extern/libspectrum"
[ -f "$fuse/settings.dat" ] && [ -f "$ls/libspectrum.h.in" ] || {
	echo "extern/fuse or extern/libspectrum is not checked out: git submodule update --init" >&2; exit 1; }
mkdir -p "$out/libspectrum" "$out/fuse/z80" "$out/fuse/debugger" "$out/fuse/ui/null"

# ---- libspectrum ----
# libspectrum.h is libspectrum.h.in with three markers replaced by a Perl
# script that a small C program writes (it knows the integer types and what
# the library was configured with).
"${CC:-cc}" -I"$here/config/libspectrum" -o "$out/libspectrum/make-perl" "$ls/make-perl.c"
{ "$out/libspectrum/make-perl"; cat "$ls/generate.pl.in"; } > "$out/libspectrum/generate.pl"
# The scripts are run from the source directory with relative names, as
# upstream's make runs them: what they are called goes into the files they
# write (comments, and #line), and a file must not say where this checkout is.
out="$(cd "$out" && pwd)"
(
	cd "$ls"
	perl -p "$out/libspectrum/generate.pl" . ./libspectrum.h.in > "$out/libspectrum/libspectrum.h"
	perl ./accessor.pl ./snap_accessors.txt > "$out/libspectrum/snap_accessors.c"
	perl ./tape_accessors.pl ./tape_accessors.txt > "$out/libspectrum/tape_accessors.c"
	perl ./tape_set.pl ./tape_accessors.txt > "$out/libspectrum/tape_set.c"
)

# ---- Fuse ----
cfg="$here/config/fuse/config.h"
(
	cd "$fuse"
	perl -I./perl ./settings.pl ./settings.dat > "$out/fuse/settings.c"
	perl -I./perl ./settings-header.pl ./settings.dat > "$out/fuse/settings.h"
	perl ./perl/cpp-perl.pl "$cfg" ./ui/options.dat | perl -I./perl ./ui/null/options-header.pl - public > "$out/fuse/options.h"
	perl ./perl/cpp-perl.pl "$cfg" ./ui/options.dat | perl -I./perl ./ui/null/options.pl - > "$out/fuse/ui/null/options.c"
	for part in opcodes_base:opcodes_base z80_cb:opcodes_cb z80_ddfd:opcodes_ddfd z80_ddfdcb:opcodes_ddfdcb z80_ed:opcodes_ed; do
		perl -I./perl ./z80/z80.pl "./z80/${part#*:}.dat" > "$out/fuse/z80/${part%%:*}.c"
	done
	# --no-lines and -L: no "#line" naming this checkout in the two parsers
	bison -y -d --no-lines -o "$out/fuse/debugger/commandy.c" ./debugger/commandy.y
	flex -L -o "$out/fuse/debugger/commandl.c" ./debugger/commandl.l
)
echo "generated: $out"
