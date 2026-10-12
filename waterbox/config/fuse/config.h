/* config.h for Fuse, written by hand.
 *
 * Fuse's own build writes this file with a configure script, which looks at
 * the machine it runs on. This core builds Fuse twice, for the host and for
 * Chimera's sandbox, and the two must be the same emulator: so this is one
 * file for both. Taken from what configure wrote for Fuse 1.9.2 with its
 * "null" user interface, and then:
 *  - NO_SOUND is gone: the core has a sound driver of its own
 *    (waterbox/chimera_sound.c) that keeps what Fuse mixes;
 *  - BUILD_SPECCYBOOT and BUILD_TTX2000S are gone: both are network
 *    devices, and a core has no network. */
#ifndef CHIMERA_FUSE_CONFIG_H
#define CHIMERA_FUSE_CONFIG_H

#define BLIP_BUFFER_ACCURACY 32
#define FUSE_COPYRIGHT "(c) 1999-2026 Philip Kendall and others"
#define FUSE_RC_VERSION 1,9,2,0
#define HAVE_DIRNAME 1
#define HAVE_ENOUGH_MEMORY 1
#define HAVE_FSYNC 1
#define HAVE_GETEUID 1
#define HAVE_GETOPT_LONG 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIBGEN_H 1
#define HAVE_LIBM 1
#define HAVE_MKSTEMP 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_STRING_STRCASECMP 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define PACKAGE "fuse"
#define PACKAGE_BUGREPORT "https://sourceforge.net/p/fuse-emulator/bugs/"
#define PACKAGE_NAME "fuse"
#define PACKAGE_STRING "fuse 1.9.2"
#define PACKAGE_TARNAME "fuse"
#define PACKAGE_URL "https://fuse-emulator.sourceforge.net/"
#define PACKAGE_VERSION "1.9.2"
#define SIZEOF_LONG 8
#define STDC_HEADERS 1
#define UI_NULL 1
#define VERSION "1.9.2"
#define YYTEXT_POINTER 1

#endif
