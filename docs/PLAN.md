# ZX Spectrum core (Fuse) - plan and design log

## What this is

A second ZX Spectrum core for Chimera, built on Fuse, the Free Unix Spectrum
Emulator. Requested in chimera issue 229: the Spectrum in Chimera's ares
core is called experimental by ares itself, and the request asks for another
core beside it, naming Fuse, SpecEmu, Spectaculator, Spud and ZX Spectrum 4.
Of those, Fuse is the one that is free software with its source available;
"Why Fuse" below says more.

Where it stands (2026-10-12). The core is built and tested and has not been
published: the repository is local, with no remote.

- Sixteen machines start and run, and the sandboxed core gives the native
  build's results on all of them.
- Tapes load, fast and as a real tape plays. Snapshots load. Savestates
  work, in the same process and carried into another.
- One game has been tried: Manic Miner, loaded from its tape and played.
- As a package it runs in Chimera's headless runner (`chimera-run`) on
  Linux and on Windows with the same pictures, and Chimera's window loads
  it under a test script.
- No disc with a program on it has been tried, and nobody has played
  anything in Chimera's window by hand.

## The pin

Fuse 1.9.2 (2026-08-26) and libspectrum 1.6.4 (the same day). Releases, and
not the head of Fuse's repository, which is in the middle of large changes
(160 commits since 1.9.2, the last ones reworking sound). libspectrum 1.7.0
is newer, and Fuse 1.9.2 does not compile against it: the tape functions
changed. zlib 1.3.1 is a third submodule, for compressed snapshots.

## The eight questions (chimera docs/new-core.md), answered from the source

- **Is it a new core?** It is a second core for a system Chimera has. That
  is what was asked for, and it uses the same system id as ares's Spectrum
  (`ZXS`), so that a user chooses between the two as between any two cores
  of one system.
- **May it be distributed and modified?** Fuse and libspectrum are GPL
  version 2 or later; zlib is under its own free licence. Inside Fuse are
  two pieces by Shay Green under the LGPL. The built core is GPL.
- **One thread on one clock?** Yes, as it comes. Fuse has no threads, and
  counts time in processor cycles (T-states); it reads the host's clock
  only to pace itself, which the core's platform layer answers with the
  machine's own time. It has recorded-input playback of its own (RZX),
  which is the same promise a TAS needs.
- **Where does the picture come from?** The machine's own screen, drawn by
  Fuse into whatever its "user interface" gives it.
- **Does it recompile?** No. An interpreter.
- **What must the user bring?** The ROMs of the machine. They are Amstrad's,
  who allow them to be distributed with emulators, and Fuse's own source
  tree has them. This core packages none: the ares core already asks the
  user for the Spectrum's ROM, and the two should not differ. One machine,
  the ZX Spectrum SE, runs on OpenSE BASIC, which is GPL.
- **What can a test run on a public runner?** Fuse's own test of its Z80,
  which needs no ROM; and, on the Spectrum SE with its free ROMs read from
  the Fuse submodule, everything else, with a tape the tests make
  themselves. Not: the other fifteen machines, Fuse's unit tests (they
  switch through every machine), and a game.
- **How big is it?** Small. The biggest machine has 1 MiB of memory.

## Why Fuse

The request names five emulators. Fuse is free software (GPL), in C, with
its own "null" user interface and a command line for every setting, both of
which made the port small. It emulates sixteen machines and reads every
common file format through libspectrum. SpecEmu, Spectaculator and Spud are
Windows programs whose source is not available, and ZX Spectrum 4 is a
closed .NET program: none of them can be built into a core.

## How it is built

Fuse builds with autoconf and automake: a `configure` script that looks at
the machine it runs on, and make rules that write some of the sources with
Perl, flex and bison. A core is built twice, for the host and for the
sandbox, and the two must be the same program, so neither is used:

- `config.h`, for Fuse and for libspectrum, is one hand-written file each
  (`waterbox/config/`), taken from what `configure` wrote for the "null"
  interface on Linux.
- `waterbox/gen-sources.sh` runs upstream's own generator scripts with the
  arguments upstream's make gives them. Measured against a real `configure`
  and `make` of the same releases: the 13 files it writes are byte for byte
  the files make wrote. (The debugger's two parsers are written without
  `#line`, and the scripts are run from the source directory with relative
  names, so that no generated file says where the checkout is.)
- `meson.build` lists the sources: what upstream's make compiled for the
  null interface, less the platform files the core replaces.

## How the core is put together

Fuse is a desktop program: a `main` that reads a command line and a
settings file, opens a window and runs until told to stop. The core changes
as little of that as it can.

- **Switched on by a call.** Patch 0001 gives Fuse an entry point in place
  of `main` (`fuse_chimera_init`) and leaves out its start-up notice. The
  adapter (`waterbox/cinterface.c`) calls it with the frontend's settings
  written as the command line Fuse already understands (`--machine 128
  --no-traps ...`) and the project's file as its last argument, which Fuse
  identifies from its contents as it does for a file named on its own
  command line. Nothing else about settings needed code.
- **Run a frame at a time.** Fuse's loop is "run the processor to the next
  event, do the events". The adapter runs that loop until the display says
  a frame has ended.
- **The display** (`chimera_ui.c`). Fuse's "null" interface is compiled as
  it is, with nine of its functions renamed by the build; the core's own
  take their place and keep the picture: 320x240, or 640x480 for the
  machines with the Timex's wide mode. The colours are those of Fuse's own
  interfaces.
- **The sound** (`chimera_sound.c`) is a sound driver in Fuse's sense: Fuse
  mixes a frame and hands it over, and the driver keeps it. 44,100 samples
  a second, stereo.
- **The platform layer** (`chimera_compat.c`) replaces Fuse's
  `compat/unix` files for paths, time, the system's name and the network.
  It names no home folder, so Fuse finds no settings file of the user's;
  its time is the machine's (frames run, over the frame rate); and there is
  no network. Fuse's `fastload` (run flat out with the sound off while a
  tape plays) is turned off: pacing is the frontend's.
- **Random numbers.** Fuse calls the C library's `rand()` in two places (a
  disc drive's speed wobble and a Microdrive cartridge's length) and seeds
  it from the clock. The C library's generator is another one in another C
  library. The build renames `rand` and `srand` for Fuse's sources to the
  core's own generator, which is seeded by nobody.
- **The keyboard was looked at.** Fuse reads the keyboard through one
  function, `keyboard_read`; the link wraps it (`-Wl,--wrap`), and a frame
  in which it was called is a frame in which the program asked for input.
  A program that reads only a Kempston joystick is not noticed: that
  port's function is private to its file.
- **Memory for tools**: the bus "System Bus", 64 KiB as the processor sees
  them, and the domain "RAM", every page Fuse keeps (1 MiB).

**Files in a sandbox have bare names.** Fuse looks for a ROM as
`<folder>/48.rom` in a list of folders. In the sandbox a file is mounted
under its bare name and `./48.rom` is not `48.rom`, so the platform layer
tells Fuse every name is to be used as given. And two calls the sandbox has
no system call for are answered in `waterbox/guest-syscalls.c`: `access`,
and `stat` of a name, both by opening the file. The first version of that
file broke `fstat` of an open file, which the C library does as `fstatat`
of an empty name: every file "did not exist", and no ROM could be read. The
same mistake was in the CHIP-8 core, where nothing depended on it; it is
fixed in both.

**Patch 0002** is one line in Fuse's unit tests, which declare an object of
type `FILE`; the sandbox's C library gives that type no size.

## Decisions

- **The ROMs are the user's**, as in the ares core. Fuse's own tree has
  them and Amstrad allows it, but what Chimera packages is the owner's to
  say, and the rule so far is that a core packages no firmware.
- **The tests use the Spectrum SE** where no ROM of Amstrad's is. Its ROMs
  are GPL, and the tests copy just those two files out of the Fuse
  submodule. Its BASIC loads an ordinary Spectrum tape, which is what makes
  the tape tests possible on a CI runner.
- **The tape starts and stops by itself** (Fuse's loader detection), with a
  setting to turn that off. The first test of the Stop button failed
  because of it: Stop stopped the tape and Fuse started it again a moment
  later. With the setting off the tape obeys Tape Play and Tape Stop alone.
- **A snapshot says which machine it is of**, and that wins over the
  Machine setting; the frame rate the core reports is read after the file
  is loaded.
- **The same key names as the ares core's Spectrum** ("Keyboard Q",
  "Keyboard CAPS SHIFT"), with the same letters in a movie, so that the two
  cores' input logs read alike. Joysticks, Reset and the tape's buttons are
  this core's own.

## What was measured (2026-10-12)

`waterbox/run-gate.sh` with `CHIMERA_ROOT` set, all 26 ROMs and the game:
15 tests, 15 passed, none skipped. With no ROMs of the user's and no game,
as on a CI runner: 13 passed, 2 skipped (Fuse's unit tests and the game),
and the tests that take a list of machines say which they could not run.

- Fuse's own test of its Z80: 1355 cases, the expected output.
- Fuse's own unit tests, natively on the core's build: none failed.
- Sixteen machines, 600 frames each with buttons pressed: the same lines
  natively and in the sandbox, and the same with a savestate saved and
  loaded before every frame. A state is about 2 MiB.
- A tape made by the tests loads on the SE, the 48K and the 128K, fast and
  real, to the same screen.
- Manic Miner: loaded from its tape, started with ENTER, played for 800
  frames (the picture shows Willy in the Central Cavern): native, sandbox
  and savestate-every-frame runs print the same lines.
- Chimera's package checks: 17 of 17.
- The window test: 3 of 3 (the SE with its ROMs set as firmware in
  Chimera's configuration, the tape's memory against the native build's, a
  setting, and 47 keys adopted).
- Windows: `chimera-run.exe` gives the pictures Linux gives, file for file,
  for the tape played from a movie on the SE (also with a savestate around
  every frame) and for Manic Miner played from a movie.
- A native build with GCC 13 runs as the GCC 14 one does (the 48K with a
  tape and keys, the 128K with its sound chip).
- An empty TR-DOS disc made by hand is taken by the Pentagon and the
  Scorpion, which start TR-DOS with it in drive A; native and sandbox
  agree. No disc with a program on it was tried.

Each test was seen to fail once:

- a stale savestate (`HARNESS_BREAK_STALE_STATE`): six of the lines
  differ;
- the frontend's picture against the runner's one frame away: 92 of
  307,200 pixels differ;
- the machines' table said the TS2068's frame is 59,136 processor cycles;
  it is 58,688, and the test said so;
- the Stop button, and the .z80 and .sna snapshot tests, each failed for a
  real reason before the test was put right (above, and "Snapshots" below);
- the sandbox could not find its ROMs (the `fstat` mistake): every machine
  failed to start.

**Snapshots, observed.** A `.z80` snapshot cannot describe the Spectrum SE
(Fuse writes what it can and the loaded machine is another); the tests use
Fuse's own `.szx` for the SE. A `.sna` snapshot does not say what is
plugged into the machine, and for the first two frames after one is loaded
the Kempston joystick port reads 15 where it should read 0. That is Fuse's
behaviour, the same natively and in the sandbox; it has not been looked
into.

## What is not done

- Discs with programs on them, on any machine.
- Settings for what Fuse can plug in besides joysticks: the Kempston mouse,
  the Interface 1 and Microdrives, the disc interfaces for the Spectrum
  (+D, DISCiPLE, Opus, Beta 128, Didaktik), the hard-disc interfaces, the
  Multiface, the sound add-ons, a printer. Their ROMs are not in the
  firmware list either.
- A project with more than one file (a tape and a disc, a game on several
  discs), and changing the tape or disc while the machine runs.
- A program that reads only a Kempston joystick is not counted as having
  asked for input.
- Fuse's own recorded input files (`.rzx`) are not played.
- Nobody has played anything in Chimera's window by hand.

## What is the owner's

- Whether to publish: a public repository
  `ToolAssisted-run/chimera-core-fuse`, the first CI run, a row in
  Chimera's list of official cores and README, the comment on issue 229.
- Whether a core may package the Spectrum's ROMs, since Amstrad allows
  their distribution with emulators and Fuse ships them. Today neither this
  core nor ares does.
- Whether to report to Fuse's authors: the unit tests do not compile with
  musl (patch 0002), and the joystick port's reading after a `.sna` load.
