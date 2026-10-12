# chimera-core-fuse

A ZX Spectrum core for [Chimera](https://github.com/ToolAssisted-run/chimera),
the frontend for tool-assisted speedruns. It is built on
[Fuse](https://fuse-emulator.sourceforge.net/), the Free Unix Spectrum
Emulator, and produces one file, `fuse.chimeraCore`, that goes in Chimera's
`Cores` folder. Chimera already has a Spectrum in its ares core, which ares
itself calls experimental; this is a second one, with more machines and more
file formats.

## Status

New. One game has been tried, Manic Miner, loaded from its tape and played;
everything else has been tried with a small test tape. Picture, sound, keys,
joysticks, tapes, snapshots and savestates work, and the sandboxed core gives
the same results as a plain native build, on Linux and on Windows.

- Sixteen machines: the 16K, 48K, 128K, +2, +2A, +3 and +3e Spectrums, the
  NTSC 48K, the Timex TC2048, TC2068 and TS2068, the Spectrum SE, the
  Pentagon 128, 512 and 1024, and the Scorpion ZS 256.
- The same input gives the same run every time.
- A tape loads in seconds, or as a real tape plays, as you choose.
- Not tried: any disc. Fuse emulates the +3's drive, the Pentagon's and
  several disc interfaces, and a disc file can be put in a project, but no
  disc image was at hand to test with.
- Not there: the Kempston mouse, the disc and hard-disc interfaces that are
  plugged in separately (+D, DISCiPLE, Opus, Beta 128 on a Spectrum, DivIDE),
  the Interface 1, the Multiface, and a project with more than one file.
  Fuse has them; this core has no settings for them yet.

## What you bring

The ROM files of the machine you choose. The Spectrum's ROMs belong to
Amstrad, who allow them to be distributed with emulators, and they come with
Fuse itself and with most other Spectrum emulators; this core does not
include them. Chimera's Firmware page lists the files a machine needs, by
the names Fuse uses (`48.rom`, `128-0.rom` and so on). The ZX Spectrum SE
needs `se-0.rom` and `se-1.rom`, which are free software and also come with
Fuse.

And a program: a tape (`.tap`, `.tzx`, `.pzx`, `.csw`), a snapshot (`.z80`,
`.sna`, `.szx`), or a disc, Microdrive or cartridge image. With none the
machine starts in its BASIC.

## Buttons and settings

The forty keys of the Spectrum's keyboard, each on the same key of yours,
with CAPS SHIFT on Shift and SYMBOL SHIFT on Ctrl. Two joysticks; the first
is on the arrow keys with Tab as fire. Tape Play, Tape Stop and Reset.

- **Machine**: which computer this is. A snapshot says which machine it was
  taken on, and that wins.
- **Joystick 1**, **Joystick 2**: what each joystick is plugged into
  (Kempston, Sinclair 1 or 2, cursor, Timex, Fuller, or nothing).
- **Tape Loading**: `fast` or `real`.
- **Load Tapes and Discs Automatically**: start what is in the project
  without typing `LOAD ""`.
- **Start and Stop the Tape by Itself**: on, the tape runs when a program
  reads it; off, it obeys Tape Play and Tape Stop only.
- **Issue 2 Keyboard**, **Late Timings**: two details in which real
  Spectrums differ from each other.

All of them are part of the machine: a movie made with one value does not
play back with another.

RAM Watch and RAM Search see the machine's memory two ways: "System Bus" is
the 64 KiB the processor sees, at the addresses a game uses; "RAM" is every
page of memory the machine has.

## Building and testing

[docs/BUILDING.md](docs/BUILDING.md) has every step. [docs/PLAN.md](docs/PLAN.md)
is the design log: what was decided, why, and what was measured.

## Licence

This repository's own code is MIT. Fuse and libspectrum are under the GNU
General Public License version 2 or later, and so are the patches to Fuse
here and the built package, which carries the licence texts of everything in
it. See [LICENSE](LICENSE).
