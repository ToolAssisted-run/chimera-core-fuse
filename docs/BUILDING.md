# Building and testing

This builds `fuse.chimeraCore` from source and runs its tests. It has been
done on Ubuntu 24.04 with GCC 14; the native build has also been made with
GCC 13, which is what a CI runner has, and runs the same.

## What is needed

- GCC (13 or 14), `meson`, `ninja`, `python3`, `git`, and for the sources
  Fuse writes while it builds: `perl`, `flex` and `bison`.
- A Chimera checkout with its submodules, built far enough to have miniBox,
  the sandbox:

  ```sh
  git clone --recurse-submodules https://github.com/ToolAssisted-run/chimera
  mb=chimera/extern/chimera-common-minibox
  meson setup $mb/build/meson-linux $mb && meson compile -C $mb/build/meson-linux
  meson setup $mb/build/meson-cpp $mb -Dguest_cpp=true && meson compile -C $mb/build/meson-cpp
  ```

  The first is the sandbox's host library; the second is the toolchain a
  core is compiled with (a C library for the sandbox, and a C++ one this
  core does not use).
- For the tests that run the package in Chimera's headless runner, Chimera's
  engine too: `meson setup build/meson-linux --prefix "$PWD/build" --libdir dll`
  and `meson compile -C build/meson-linux` in the Chimera checkout. For the
  window test, Chimera's window as well (`dotnet build`), `mono` and `Xvfb`.
  Chimera's README lists what those need.

Nothing is downloaded while building, and upstream's `configure` and `make`
are not used ("How it is built", in docs/PLAN.md, says why).

## The sources

```sh
git clone --recurse-submodules https://github.com/ToolAssisted-run/chimera-core-fuse
```

`extern/fuse` is Fuse 1.9.2 and `extern/libspectrum` is libspectrum 1.6.4.
The patches in `patches/` are applied to Fuse by `waterbox/apply-patches.sh`,
which the build runs by itself; a tree that already has them is left alone,
and one that has only some of them stops the build and says which files.

## The builds

```sh
# the native reference, the sandbox runner, and Fuse's own Z80 test
meson setup build/meson-native -Dminibox_dir=<chimera>/extern/chimera-common-minibox
ninja -C build/meson-native

# the sandboxed core and the package, installed into <chimera>/build/Cores
waterbox/build-package.sh -r <chimera>
```

- `build/meson-native/run-native` is the core compiled for the host:
  `waterbox/cinterface.c` and Fuse, with nothing of the sandbox.
- `build/meson-guest/core.wbx` is the same sources compiled for the sandbox.
  `build-package.sh` configures that build the first time
  (`waterbox/setup-guest.sh -m <miniBox>`), checks the result
  (`check-wbx.sh`: nothing in it may use thread-local storage), and writes
  the package.
- `build/meson-native/run-wbx` runs `core.wbx` in the sandbox the way
  Chimera's engine does.
- Each build directory has a `gen/` folder with the sources upstream's make
  would have written (`waterbox/gen-sources.sh`).

## ROMs and games for the tests

The ROMs of twelve machines are built into the core when it is built, from
the Fuse submodule's `roms/` directory (`waterbox/gen-roms.py`), so those
machines need nothing. The Pentagon 128, 512 and 1024 and the Scorpion do:
the tests look for their ROM files, by Fuse's names for them, in the folder
`FUSE_TEST_ROMS` names, or in `tests/roms-local/` (ignored by git). They are
in the usual collections of Spectrum ROMs. Seven files:

    128p-0.rom trdos.rom gluck.rom
    256s-0.rom 256s-1.rom 256s-2.rom 256s-3.rom

Without them the tests run on the other twelve machines, which is what a CI
runner does, and say that those four were not run.

One test plays a game: Manic Miner (Software Projects, 1983), from the tape
`FUSE_TEST_GAME` names or `tests/games-local/Manic Miner (Software
Projects).tzx`.

## The tests

```sh
CHIMERA_ROOT=<chimera> waterbox/run-gate.sh
bash waterbox/tests/run-frontend.sh --chimera-root <chimera>
```

Each line says what was compared. The first script ends with a count of
tests that passed, failed and were skipped, and exits with an error if any
failed. A skipped test is not a pass. Without `CHIMERA_ROOT` the four
`frontend:` tests are skipped.

- `upstream:z80` - Fuse's own test of its Z80 (1355 cases).
- `upstream:unittests` - Fuse's own unit tests, natively. They switch
  through every machine, so they need the seven ROMs above.
- `machines:sandbox` - every machine whose ROMs are there, switched on and
  run 600 frames with buttons pressed: the sandboxed core prints the native
  build's lines (where the processor is, the memory, the sound, the picture
  and every picture on the way), and is the machine, frame rate and picture
  size it should be.
- `state:every-frame`, `state:other-process` - a savestate saved and loaded
  before every frame changes nothing; one saved by one process and loaded
  by another ends where the unbroken run ends.
- `tape:loading` - a tape the script makes (`tests/make-tape.py`) loads
  fast and as a real tape plays, and both end with the same screen.
- `input:buttons`, `input:tape-and-reset` - keys, a Kempston and a Sinclair
  joystick, the tape's Play and Stop, and Reset.
- `snapshot:load` - a snapshot Fuse wrote starts as the machine and with
  the screen it was taken of.
- `settings:refused` - what cannot be run is refused with a reason.
- `roms:built-in` - the built-in ROMs are Fuse's files, and a file of the
  same name lying beside a machine does not replace one.
- `game:manic-miner` - the game loaded and played.
- `frontend:picture`, `frontend:states`, `frontend:movie`,
  `frontend:firmware` - the package in Chimera's headless runner.

The window test loads the package in Chimera's own window, on a virtual
display with nobody at it, and asks three things: that the tape's memory
after 300 frames is the native build's (`window:memory`), that a setting
made in Chimera's configuration reaches the machine (`window:setting`), and
that the keys the package ships become Chimera's (`window:keys`).

Chimera's own checks of the package (it loads, and its buttons, settings,
firmware and file types are well formed) are run from the Chimera checkout:

```sh
CHIMERA_CORES_DIR=<chimera>/build/Cores dotnet test \
  source/gui/Chimera.Tests.Client.Common/Chimera.Tests.Client.Common.csproj -c Release \
  --filter "FullyQualifiedName~InstalledCorePackagesTests|FullyQualifiedName~MnemonicUniquenessTests"
```

## Running a program by hand

```sh
build/meson-native/run-native <program or -> <a new folder> --roms <ROMs> --frames 600 --every 60 --ppm out.ppm
build/meson-native/run-wbx build/meson-guest/core.wbx <program or -> --roms <ROMs> --frames 600 --every 60 --ppm out.ppm
<chimera>/build/meson-linux/chimera-run <chimera>/build/Cores/fuse.chimeraCore <program> <movie>
```

The two runners take the same options (`waterbox/gate-harness.h` lists
them): `--set NAME=VALUE` is one of the package's settings, `--press
F:N:MASK` holds buttons, `--exercise` presses them by a fixed pattern. `-`
in place of a program starts the machine with nothing in it. A line shows
the frame, where the processor is in the frame, whether the tape is moving,
the frames in which the program looked at the keyboard, the sound and
memory digests, the picture's size and digest, and a digest of every
picture so far.

`chimera-run` plays a movie: to run frames with no buttons, give it an
empty file as the movie and `--frames N --record <file>`. Without `--record`
an empty movie has no frames to play. For a Pentagon or the Scorpion each
ROM is handed over with `--firmware <name>=<file>`; the runners take
`--roms <folder>`.

## What CI does

`.github/workflows/chimera.yml` builds everything above from a fresh clone
on a public runner, runs the test script, the window test and Chimera's
package checks, and publishes the package. A runner has no Pentagon or
Scorpion ROM and no game, so there the tests run on the twelve machines
whose ROMs are built in; Fuse's unit tests and the game are skipped, and the
workflow asks for the others by name, so that a run that skipped everything
cannot pass.

## When something goes wrong

- `extern/fuse is partly patched`: a file under `extern/fuse` was edited
  without updating the patches. Run `waterbox/make-patches.sh` (add the file
  to its list first if it is a new one), or start again as the message says.
- `couldn't find ROM '128p-0.rom'` (or another): a Pentagon's or the
  Scorpion's ROM was not handed over (`--roms`, `--firmware`, or Chimera's
  Firmware page).
- `the core asked for system call N, which the sandbox does not provide`:
  something in Fuse called the operating system in a way the sandbox does
  not have. `waterbox/guest-syscalls.c` is where such calls are answered.
- The native run and the sandbox run print different lines: look for the
  host's clock, the C library's `rand()`, or memory nobody wrote. The first
  line that differs says the frame.
