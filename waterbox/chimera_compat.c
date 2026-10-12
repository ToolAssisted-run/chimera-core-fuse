/* The parts of Fuse's platform layer that a core answers differently from a
 * desktop program: where files are looked for, what time it is, which
 * system this is, and the network (there is none). Fuse's own versions are
 * compat/unix/paths.c, timer.c, osname.c, tuntap.c and socket.c; its dir.c
 * and file.c, which are plain C library calls, are used as they are.
 *
 * Nothing here reads the user's home folder or the host's clock: a core is
 * told everything by the frontend, and its time is the machine's. */
#include "config.h"

#include <stdio.h>
#include <string.h>

#include "compat.h"
#include "chimera_glue.h"

double chimera_machine_seconds;

int compat_osname(char *buffer, size_t length)
{
	snprintf(buffer, length, "Chimera");
	return 0;
}

/* Nothing is written anywhere; a temporary file would have nowhere to go. */
const char *compat_get_temp_path(void) { return "."; }

/* Fuse reads its settings file from here when it starts. A folder that
 * holds no such file: the settings are the frontend's. */
const char *compat_get_config_path(void) { return "/chimera-no-settings-file"; }
const char *compat_get_fallback_config_path(void) { return NULL; }

/* Fuse asks this before it puts a folder in front of a file's name (a ROM's,
 * above all). In a sandbox a file is mounted under its bare name and there
 * are no folders: "./48.rom" is not "48.rom". So every name is taken as it
 * is given - which is also where the native runner puts its files, in the
 * folder it runs in. */
int compat_is_absolute_path(const char *path) { (void)path; return 1; }

/* never reached while every name is taken as given; no folder to offer */
int compat_get_next_path(path_context *ctx) { (void)ctx; return 0; }

double compat_timer_get_time(void) { return chimera_machine_seconds; }
void compat_timer_sleep(int ms) { (void)ms; }

/* no network */
int compat_get_tap(const char *interface_name) { (void)interface_name; return -1; }
const compat_socket_t compat_socket_invalid = -1;
const int compat_socket_EBADF = EBADF;
void compat_socket_networking_init(void) {}
void compat_socket_networking_end(void) {}
int compat_socket_blocking_mode(compat_socket_t fd, int blocking) { (void)fd; (void)blocking; return -1; }
int compat_socket_get_fionread(compat_socket_t fd, u_long *bytes) { (void)fd; *bytes = 0; return -1; }
int compat_socket_close(compat_socket_t fd) { (void)fd; return 0; }
int compat_socket_get_error(void) { return 0; }
const char *compat_socket_get_strerror(void) { return "there is no network in a core"; }
compat_socket_selfpipe_t *compat_socket_selfpipe_alloc(void) { return NULL; }
void compat_socket_selfpipe_free(compat_socket_selfpipe_t *self) { (void)self; }
compat_socket_t compat_socket_selfpipe_get_read_fd(compat_socket_selfpipe_t *self) { (void)self; return -1; }
void compat_socket_selfpipe_wake(compat_socket_selfpipe_t *self) { (void)self; }
void compat_socket_selfpipe_discard_data(compat_socket_selfpipe_t *self) { (void)self; }
