# AGENTS.md - ZX Spectrum core (Fuse) for Chimera

This repository builds Fuse (https://fuse-emulator.sourceforge.net/), the
Free Unix Spectrum Emulator, written in C, as a core for Chimera
(https://github.com/ToolAssisted-run/chimera), a frontend for tool-assisted
speedruns. It produces one file, `fuse.chimeraCore`: Fuse compiled to run
inside Chimera's sandbox (miniBox), a thin layer that runs the machine one
television frame at a time, and the declarations Chimera reads (buttons,
settings, file types, firmware). Fuse and its library libspectrum are git
submodules at fixed releases; every change to Fuse is a numbered patch. The
picture is the emulated machine's own.

Read [docs/BUILDING.md](docs/BUILDING.md) before building and
[docs/PLAN.md](docs/PLAN.md) before changing how the core works: it is the
design log, with what was decided, why, and what was measured.

## Layout

- `extern/fuse`, `extern/libspectrum` - Fuse 1.9.2 and libspectrum 1.6.4, the
  release Fuse 1.9.2 was made against (1.7.0 no longer fits it).
  `extern/zlib` - zlib, for compressed snapshots.
- `patches/` - the numbered patches applied to `extern/fuse`.
- `meson.build` - the build of both flavours, with the lists of sources.
  `waterbox/config/` - the two `config.h` files, written by hand.
  `waterbox/gen-sources.sh` - writes, into the build directory, the sources
  upstream's make writes (with Perl, flex and bison).
- `waterbox/cinterface.c` - the core: the functions Chimera's engine calls.
  The same file is compiled for the sandbox and for the host.
- `waterbox/chimera_ui.c`, `chimera_sound.c`, `chimera_compat.c` - the core's
  own display, sound card and platform layer under Fuse. `chimera_glue.h` is
  what they share with `cinterface.c`.
- `waterbox/chimera_roms.c`, `gen-roms.py` - the ROMs built into the core,
  and how Fuse is given them (through its replaceable table of file
  functions). A built-in ROM wins over a file of the same name.
- `waterbox/guest-syscalls.c` - answers, in the sandbox only, file questions
  the sandbox has no system call for.
- `waterbox/run-native.c`, `waterbox/run-wbx.c` - the native runner and the
  sandbox runner. They take the same options and print the same lines
  (`waterbox/gate-harness.h` is the part they share).
- `waterbox/*.sh` - `setup-guest.sh` (configures the sandbox build),
  `build-package.sh`, `run-gate.sh` (the test script), `apply-patches.sh`
  and `make-patches.sh`.
- `waterbox/tests/` - the window test (`run-frontend.sh`, with its Lua
  scripts and helpers), `make-tape.py` (writes the tape the tests load) and
  `make-movie.py`.
- `waterbox/waterbox.config`, `file_slots.json`, `default_keybinds.json`,
  `package-licenses.json` - what the package declares.
- `.github/workflows/chimera.yml` - CI: build, test, publish.
- `build/` - every build output. `tests/roms-local/` - ROMs, and
  `tests/games-local/` - games, for the tests that need them. All three are
  ignored by git.

## Build and test

```sh
git submodule update --init
meson setup build/meson-native -Dminibox_dir=<chimera>/extern/chimera-common-minibox
ninja -C build/meson-native
waterbox/build-package.sh -r <chimera>
CHIMERA_ROOT=<chimera> waterbox/run-gate.sh
bash waterbox/tests/run-frontend.sh --chimera-root <chimera>
```

The test script must end with `0 failed`. Run it before every commit that
changes the core, and say in the commit what it printed.

Four machines (the Pentagons and the Scorpion) need ROM files this
repository cannot contain (`FUSE_TEST_ROMS`, or `tests/roms-local/`), and one
test needs a game (`FUSE_TEST_GAME`, or `tests/games-local/`). Without them
the script runs everything on the twelve machines whose ROMs are built in,
and says what it skipped or could not run. A skipped test proves nothing: if
you do not have the ROMs or the game, say so in your report.

## Rules

- **Never edit `patches/` by hand.** Edit the tree under `extern/fuse`, add
  the file to the list in `waterbox/make-patches.sh` if it is new, and run
  that script. `waterbox/apply-patches.sh` must then say "already applied".
- **Patch as little as possible.** Fuse is told what to do by its own
  command line (`cinterface.c` writes one), its platform functions are
  replaced by linking the core's own, and single functions are renamed or
  wrapped by the build (`meson.build`). Two patches were needed so far.
- **The native run is the reference.** `run-native` and `run-wbx` must print
  the same lines for the same input. A change that makes them differ is
  wrong even when both look right.
- **The same input gives the same run, every time.** Nothing may read the
  host's clock or the user's home folder, or use the C library's `rand()`
  (the build sends Fuse's two uses of it to the core's own generator).
- **No ROM and no game is committed.** The ROMs of twelve machines are built
  into the core from the Fuse submodule's `roms/` directory when it is
  built (`waterbox/gen-roms.py`; the owner's decision, 2026-10-12), and that
  is the only way a ROM gets anywhere. The list in that script is the
  machines' ROMs Fuse is distributed with; adding a file that Fuse does not
  ship is the owner's to decide. The Pentagon's and Scorpion's ROMs stay
  firmware the user supplies.
- **A new test is broken on purpose once and seen to fail.** docs/PLAN.md
  says how each one was.
- **Write in plain language.** Commit messages, documents and the
  descriptions a user reads in Chimera (a setting's, a file slot's, a
  firmware file's) say what they mean in ordinary words.
- **Commits.** Subject: `type(scope): what changed`. Body: what changed,
  why, and how it was tested, with the numbers. Stage explicit paths. No
  amending, no force push.

## What is the owner's to decide

Publishing a repository, a place in Chimera's list of official cores,
anything a licence does not plainly allow (packaging another ROM, above all), and
reporting anything to Fuse's authors.
