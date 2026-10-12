# chimera-core-fuse: Fuse, the Free Unix Spectrum Emulator, in miniBox's
# sandbox, as a Chimera core.
#
# Native reference build (run-native + run-wbx under the build directory):
#     meson setup build/meson-native -Dminibox_dir=<miniBox> && ninja -C build/meson-native
# Guest (core.wbx) build via the cross file waterbox/setup-guest.sh writes
# (needs miniBox's guest toolchain):
#     sh waterbox/setup-guest.sh -m <miniBox> && ninja -C build/meson-guest core.wbx
#
# Upstream builds with autoconf and automake: a configure script that looks
# at the machine, and make rules that write some of the sources. Neither is
# used here, because the core is built twice (host and sandbox) and the two
# must be the same program:
#  - config.h, for Fuse and for libspectrum, is one hand-written file each
#    (waterbox/config/);
#  - the written sources come from upstream's own scripts, run by
#    waterbox/gen-sources.sh into the build directory;
#  - the source lists below are what upstream's make compiled for the "null"
#    user interface, less the platform files the core replaces.
project('chimera-core-fuse', 'c',
  default_options: ['c_std=gnu11', 'optimization=2', 'debug=false', 'warning_level=0'])

fu = 'extern/fuse'
ls = 'extern/libspectrum'
zl = 'extern/zlib'

# the submodule pin is upstream as it is; the patches are laid over it
run_command(files('waterbox/apply-patches.sh'), check: true)
# the sources upstream's make writes, written into this build's own directory
gen = meson.current_build_dir() / 'gen'
run_command(files('waterbox/gen-sources.sh'), gen, check: true)

mb = get_option('minibox_dir')
if mb == ''
  mb_candidate = meson.current_source_dir() / '../chimera/extern/chimera-common-minibox'
  if import('fs').is_dir(mb_candidate)
    mb = mb_candidate
  else
    error('pass -Dminibox_dir=<miniBox checkout> (or keep one at ../chimera/extern/chimera-common-minibox)')
  endif
endif

quiet = [
  '-fno-strict-aliasing',
  # one answer from a floating-point expression on every machine (the sound
  # filters are floating point)
  '-ffp-contract=off',
]
add_project_arguments(quiet, language: 'c')

# ---- zlib: compressed snapshots and archives ---------------------------------
zlib = static_library('z', files(
    zl / 'adler32.c', zl / 'compress.c', zl / 'crc32.c', zl / 'deflate.c', zl / 'inffast.c',
    zl / 'inflate.c', zl / 'inftrees.c', zl / 'trees.c', zl / 'uncompr.c', zl / 'zutil.c',
  ),
  include_directories: include_directories(zl),
  c_args: ['-DHAVE_UNISTD_H'])

# ---- libspectrum: the file formats -----------------------------------------
ls_inc = include_directories('waterbox/config/libspectrum', ls, ls / 'myglib', zl)
libspectrum = static_library('spectrum', files(
    ls / 'buffer.c', ls / 'bzip2.c', ls / 'creator.c', ls / 'crypto.c', ls / 'csw.c', ls / 'dck.c',
    ls / 'dsnap.c', ls / 'ide.c', ls / 'libspectrum.c', ls / 'memory.c', ls / 'microdrive.c',
    ls / 'mmc.c', ls / 'myglib/garray.c', ls / 'myglib/ghash.c', ls / 'myglib/glock.c',
    ls / 'myglib/gslist.c', ls / 'plusd.c', ls / 'pzx_read.c', ls / 'rzx.c', ls / 'sna.c',
    ls / 'snapshot.c', ls / 'snp.c', ls / 'sp.c', ls / 'symbol_table.c', ls / 'szx.c', ls / 'tap.c',
    ls / 'tape.c', ls / 'tape_block.c', ls / 'timings.c', ls / 'tzx_read.c', ls / 'tzx_write.c',
    ls / 'utilities.c', ls / 'warajevo_read.c', ls / 'z80.c', ls / 'z80em.c', ls / 'zip.c',
    ls / 'zlib.c', ls / 'zxs.c',
    gen / 'libspectrum/snap_accessors.c', gen / 'libspectrum/tape_accessors.c', gen / 'libspectrum/tape_set.c',
  ),
  include_directories: [include_directories('.'), ls_inc],
  c_args: ['-DHAVE_CONFIG_H', '-I' + gen / 'libspectrum'])

# ---- Fuse --------------------------------------------------------------------
fuse_inc = include_directories('waterbox/config/fuse', 'waterbox', fu)
fuse_args = [
  '-DHAVE_CONFIG_H', '-DCHIMERA_CORE',
  '-I' + gen / 'fuse', '-I' + gen / 'libspectrum',
  '-DFUSEDATADIR="."',
  # Fuse's two uses of the C library's random numbers, and its seeding of
  # them from the clock, go to the core's own (waterbox/cinterface.c)
  '-Drand=chimera_rand', '-Dsrand=chimera_srand',
]
fuse_sources = files(
  fu / 'display.c', fu / 'event.c', fu / 'fuse.c', fu / 'input.c', fu / 'keyboard.c',
  fu / 'loader.c', fu / 'machine.c', fu / 'memory_pages.c', fu / 'mempool.c',
  fu / 'menu.c', fu / 'movie.c', fu / 'module.c', fu / 'periph.c', fu / 'phantom_typist.c',
  fu / 'profile.c', fu / 'psg.c', fu / 'rectangle.c', fu / 'rzx.c',
  fu / 'screenshot.c', fu / 'slt.c', fu / 'snapshot.c', fu / 'sound.c', fu / 'spectrum.c', fu / 'svg.c',
  fu / 'tape.c', fu / 'ui.c', fu / 'uidisplay.c', fu / 'uimedia.c', fu / 'utils.c',
  # the platform layer's plain C library parts; the rest is waterbox/chimera_compat.c
  fu / 'compat/unix/dir.c', fu / 'compat/unix/file.c',
  fu / 'debugger/breakpoint.c', fu / 'debugger/command.c', fu / 'debugger/debugger.c',
  fu / 'debugger/disassemble.c', fu / 'debugger/event.c', fu / 'debugger/expression.c',
  fu / 'debugger/system_variable.c', fu / 'debugger/variable.c',
  fu / 'infrastructure/startup_manager.c',
  fu / 'machines/machines_periph.c', fu / 'machines/pentagon.c', fu / 'machines/pentagon512.c',
  fu / 'machines/pentagon1024.c', fu / 'machines/scorpion.c', fu / 'machines/spec128.c',
  fu / 'machines/spec16.c', fu / 'machines/spec48.c', fu / 'machines/spec48_ntsc.c',
  fu / 'machines/specplus2.c', fu / 'machines/spec_se.c', fu / 'machines/specplus2a.c',
  fu / 'machines/specplus3.c', fu / 'machines/specplus3e.c', fu / 'machines/tc2048.c',
  fu / 'machines/tc2068.c', fu / 'machines/ts2068.c',
  fu / 'peripherals/dck.c', fu / 'peripherals/if1.c', fu / 'peripherals/if2.c',
  fu / 'peripherals/joystick.c', fu / 'peripherals/kempmouse.c', fu / 'peripherals/multiface.c',
  fu / 'peripherals/printer.c', fu / 'peripherals/scld.c', fu / 'peripherals/speccyboot.c',
  fu / 'peripherals/spectranet.c', fu / 'peripherals/ula.c', fu / 'peripherals/usource.c',
  fu / 'peripherals/ttx2000s.c',
  fu / 'peripherals/sound/ay.c', fu / 'peripherals/sound/covox.c', fu / 'peripherals/sound/fuller.c',
  fu / 'peripherals/sound/melodik.c', fu / 'peripherals/sound/sp0256.c',
  fu / 'peripherals/sound/specdrum.c', fu / 'peripherals/sound/uspeech.c',
  fu / 'peripherals/disk/beta.c', fu / 'peripherals/disk/crc.c', fu / 'peripherals/disk/didaktik.c',
  fu / 'peripherals/disk/disciple.c', fu / 'peripherals/disk/disk.c', fu / 'peripherals/disk/fdd.c',
  fu / 'peripherals/disk/opus.c', fu / 'peripherals/disk/plusd.c', fu / 'peripherals/disk/trdos.c',
  fu / 'peripherals/disk/upd_fdc.c', fu / 'peripherals/disk/wd_fdc.c',
  fu / 'peripherals/ide/divide.c', fu / 'peripherals/ide/divmmc.c', fu / 'peripherals/ide/divxxx.c',
  fu / 'peripherals/ide/ide.c', fu / 'peripherals/ide/simpleide.c', fu / 'peripherals/ide/zxatasp.c',
  fu / 'peripherals/ide/zxcf.c', fu / 'peripherals/ide/zxmmc.c',
  fu / 'peripherals/nic/enc28j60.c',
  fu / 'pokefinder/pokefinder.c', fu / 'pokefinder/pokemem.c',
  fu / 'sound/blipbuffer.c', fu / 'sound/speaker_filter.c', fu / 'sound/ula_filter.c',
  fu / 'timer/timer.c', fu / 'timer/native.c',
  fu / 'ui/scaler/scaler.c', fu / 'ui/scaler/snes_ntsc.c',
  fu / 'z80/z80.c', fu / 'z80/z80_debugger_variables.c', fu / 'z80/z80_ops.c',
  gen / 'fuse/settings.c', gen / 'fuse/ui/null/options.c',
  gen / 'fuse/debugger/commandy.c', gen / 'fuse/debugger/commandl.c',
  # the core's own layers
  'waterbox/chimera_compat.c', 'waterbox/chimera_sound.c', 'waterbox/chimera_ui.c',
  # the ROMs Fuse is distributed with, built in, and the way Fuse is given them
  'waterbox/chimera_roms.c', gen / 'chimera_roms_data.c',
)
# Fuse's "null" interface, with the functions the core answers itself
# compiled under other names (waterbox/chimera_ui.c has the real ones)
renamed = []
foreach f : ['uidisplay_init', 'uidisplay_end', 'uidisplay_hotswap_gfx_mode', 'uidisplay_area',
             'uidisplay_frame_end', 'uidisplay_putpixel', 'uidisplay_plot8', 'uidisplay_plot16',
             'ui_error_specific']
  renamed += '-D' + f + '=null_' + f
endforeach
null_ui = static_library('null-ui', files(fu / 'ui/null/null_ui.c'),
  include_directories: fuse_inc, c_args: fuse_args + renamed)

# upstream compiles its picture scalers twice from one file, for 16-bit and
# for 32-bit pixels
scalers16 = static_library('scalers16', files(fu / 'ui/scaler/scalers.c'),
  include_directories: fuse_inc, c_args: fuse_args + ['-DSCALER_DATA_SIZE=2'])
scalers32 = static_library('scalers32', files(fu / 'ui/scaler/scalers.c'),
  include_directories: fuse_inc, c_args: fuse_args + ['-DSCALER_DATA_SIZE=4'])
# Fuse's own unit tests (fuse --unittests), kept in the core so that the
# tests can run them in the sandbox as well as natively.
unittests = static_library('unittests', files(fu / 'unittests/unittests.c'),
  include_directories: fuse_inc, c_args: fuse_args)
fuse_libs = [null_ui, scalers16, scalers32, unittests, libspectrum, zlib]

link_wrap = ['-Wl,--wrap=keyboard_read']

if meson.is_cross_build()
  # ---- the guest: core.wbx --------------------------------------------------
  mbdir = meson.get_external_property('minibox_dir')
  mbuild = meson.get_external_property('minibox_build')
  sr = meson.get_external_property('guest_sysroot')

  executable('core', fuse_sources + files('waterbox/cinterface.c', 'waterbox/guest-syscalls.c'),
    name_suffix: 'wbx',
    include_directories: fuse_inc,
    c_args: fuse_args,
    link_with: fuse_libs,
    link_args: link_wrap + [
      '-static', '-no-pie',
      '-Wl,--eh-frame-hdr', '-Wl,-O2', '-Wl,--no-relax', '-Wl,-z,stack-size=8388608',
      '-T', mbdir / 'source/guest/linkscript.T',
      mbuild / 'source/guest/emulibc.c.o',
      '-L' + sr / 'lib', '-lgcc', '-lc'])
else
  # ---- the native reference -------------------------------------------------
  m = meson.get_compiler('c').find_library('m', required: false)
  executable('run-native', fuse_sources + files('waterbox/cinterface.c', 'waterbox/run-native.c'),
    include_directories: [include_directories('waterbox/native-shim'), fuse_inc],
    c_args: fuse_args + ['-I' + mb / 'source/guest/include', '-I' + mb / 'extern/jsmn'],
    link_with: fuse_libs,
    link_args: link_wrap,
    dependencies: [m])

  # Fuse's own test of its Z80: the processor alone, run through a file of
  # cases (z80/tests/tests.in) and compared with z80/tests/tests.expected.
  # Built as upstream builds it, with CORETEST.
  executable('z80-coretest', files(fu / 'z80/coretest.c', fu / 'z80/z80.c', fu / 'z80/z80_ops.c'),
    include_directories: fuse_inc,
    c_args: fuse_args + ['-DCORETEST'],
    link_with: [libspectrum, zlib],
    dependencies: [m])

  mbhost = mb / 'build/meson-linux/source/host'
  executable('run-wbx', files('waterbox/run-wbx.c'),
    c_args: ['-I' + mb / 'source/host'],
    link_args: [mbhost / 'libminiboxhost.so'],
    build_rpath: mbhost)
endif
