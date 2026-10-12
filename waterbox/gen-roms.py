#!/usr/bin/env python3
"""Writes the ROMs that go into the core, as a C file.

  gen-roms.py <Fuse's roms directory> <C file to write>

The machines' ROMs that Fuse itself is distributed with are built into the
core (user-decided, 2026-10-12: docs/PLAN.md), so that a user has nothing to
find for those machines. They are read from the pinned Fuse submodule when
the core is built; this repository holds no ROM. Fuse's roms/README.copyright
says whose each is and on what terms it may be distributed, and the package
carries that file.

Not here, because Fuse does not have them: the Pentagon's and the Scorpion's
own ROMs, which stay firmware the user supplies. The Pentagon's second ROM is
the same 16 KiB as the Spectrum 128's second ROM (48 BASIC), so it is given
under both names.
"""
import sys

# the files of Fuse's roms/ that are a machine's ROM
ROMS = ["48.rom", "128-0.rom", "128-1.rom", "plus2-0.rom", "plus2-1.rom",
        "plus3-0.rom", "plus3-1.rom", "plus3-2.rom", "plus3-3.rom",
        "plus3e-0.rom", "plus3e-1.rom", "plus3e-2.rom", "plus3e-3.rom",
        "tc2048.rom", "tc2068-0.rom", "tc2068-1.rom", "se-0.rom", "se-1.rom"]
# another name for the same bytes
ALIASES = {"128p-1.rom": "128-1.rom"}


def ident(name):
    return "rom_" + name.replace(".", "_").replace("-", "_")


def main():
    folder, out_path = sys.argv[1], sys.argv[2]
    out = ['/* Written by waterbox/gen-roms.py from Fuse\'s roms/ directory. Not edited by hand. */',
           '#include "chimera_roms.h"', ""]
    for name in ROMS:
        data = open(folder + "/" + name, "rb").read()
        out.append("static const unsigned char %s[%d] = {" % (ident(name), len(data)))
        for i in range(0, len(data), 16):
            out.append("\t" + ",".join("%d" % b for b in data[i:i + 16]) + ",")
        out.append("};")
    out.append("")
    out.append("const struct chimera_rom chimera_roms[] = {")
    for name in ROMS:
        out.append('\t{ "%s", %s, sizeof %s },' % (name, ident(name), ident(name)))
    for name, same in ALIASES.items():
        out.append('\t{ "%s", %s, sizeof %s },' % (name, ident(same), ident(same)))
    out.append("\t{ 0, 0, 0 },")
    out.append("};")
    open(out_path, "w").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
