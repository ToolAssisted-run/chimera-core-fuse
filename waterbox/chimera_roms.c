/* Fuse is given the ROMs that are built into the core.
 *
 * Fuse reads every file through a small table of functions (open, length,
 * read, close, exists) that can be replaced - its own tests replace it. The
 * core's table answers for the names of the built-in ROMs from the core's
 * own memory, and hands every other name to the table that was there.
 *
 * A built-in ROM wins over a file of the same name: what a machine runs on
 * must not depend on what happens to be mounted beside it. */
#include "config.h"

#include <string.h>

#include "compat.h"
#include "utils.h"
#include "chimera_roms.h"

static compat_file_vtable_t files;

/* An open built-in ROM. Fuse holds it as a FILE pointer and never looks
 * inside one; these are told from real files by where they are. */
static const struct chimera_rom *open_roms[8];

static const struct chimera_rom *find(const char *path)
{
	const char *slash = strrchr(path, '/');
	const char *name = slash ? slash + 1 : path;
	for (const struct chimera_rom *r = chimera_roms; r->name; r++)
		if (!strcmp(r->name, name)) return r;
	return NULL;
}

static int slot_of(compat_fd fd)
{
	const char *p = (const char *)fd, *base = (const char *)open_roms;
	if (p < base || p >= base + sizeof open_roms) return -1;
	return (int)((p - base) / sizeof open_roms[0]);
}

static compat_fd rom_open(const char *path, int write)
{
	const struct chimera_rom *r = write ? NULL : find(path);
	if (!r) return files.open(path, write);
	for (size_t i = 0; i < sizeof open_roms / sizeof open_roms[0]; i++) {
		if (!open_roms[i]) {
			open_roms[i] = r;
			return (compat_fd)&open_roms[i];
		}
	}
	return COMPAT_FILE_OPEN_FAILED;
}

static off_t rom_get_length(compat_fd fd)
{
	const int slot = slot_of(fd);
	return slot < 0 ? files.get_length(fd) : (off_t)open_roms[slot]->size;
}

static int rom_read(compat_fd fd, struct utils_file *file)
{
	const int slot = slot_of(fd);
	if (slot < 0) return files.read(fd, file);
	if (file->length != open_roms[slot]->size) return 1;
	memcpy(file->buffer, open_roms[slot]->data, file->length);
	return 0;
}

static int rom_write(compat_fd fd, const unsigned char *buffer, size_t length)
{
	return slot_of(fd) < 0 ? files.write(fd, buffer, length) : 1;
}

static int rom_close(compat_fd fd)
{
	const int slot = slot_of(fd);
	if (slot < 0) return files.close(fd);
	open_roms[slot] = NULL;
	return 0;
}

static int rom_exists(const char *path)
{
	return find(path) ? 1 : files.exists(path);
}

void chimera_roms_install(void)
{
	static compat_file_vtable_t roms = { rom_open, rom_get_length, rom_read, rom_write, rom_close, rom_exists };
	compat_file_get_vtable(&files);
	compat_file_set_vtable(&roms);
}
