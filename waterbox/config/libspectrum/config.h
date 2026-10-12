/* config.h for libspectrum, written by hand.
 *
 * libspectrum's own build writes this file with a configure script, which
 * looks at the machine it runs on. This core builds libspectrum twice, for
 * the host and for Chimera's sandbox, and the two must be the same library:
 * so this is one file for both, saying what both have. Taken from what
 * configure wrote for libspectrum 1.6.4 on Linux with its internal GLib
 * replacement, zlib, and no bzip2, libgcrypt or audiofile. */
#ifndef CHIMERA_LIBSPECTRUM_CONFIG_H
#define CHIMERA_LIBSPECTRUM_CONFIG_H

#define HAVE_INTTYPES_H 1
#define HAVE_SNPRINTF 1
#define HAVE_STDATOMIC_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRCASECMP 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_STRNCASECMP 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
/* compressed snapshots (.szx, .z80 inside .zip or .gz): the zlib in extern/zlib */
#define HAVE_ZLIB_H 1
#define LIBSPECTRUM_COPYRIGHT "(c) 1999-2026 Philip Kendall and others"
#define LIBSPECTRUM_RC_VERSION 1,6,4,0
#define PACKAGE "libspectrum"
#define PACKAGE_BUGREPORT "https://sourceforge.net/p/fuse-emulator/bugs/"
#define PACKAGE_NAME "libspectrum"
#define PACKAGE_STRING "libspectrum 1.6.4"
#define PACKAGE_TARNAME "libspectrum"
#define PACKAGE_URL "https://fuse-emulator.sourceforge.net/libspectrum.php"
#define PACKAGE_VERSION "1.6.4"
#define STDC_HEADERS 1
#define VERSION "1.6.4"

#endif
