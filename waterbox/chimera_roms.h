/* The ROMs built into the core, and the way Fuse is given them. */
#ifndef CHIMERA_FUSE_ROMS_H
#define CHIMERA_FUSE_ROMS_H

#include <stddef.h>

struct chimera_rom {
	const char *name;          /* Fuse's name for the file: "48.rom" */
	const unsigned char *data;
	size_t size;
};
/* ended by an entry with no name; written by waterbox/gen-roms.py */
extern const struct chimera_rom chimera_roms[];

/* From now on, Fuse opening a file by one of those names gets the ROM that
 * is built in. Any other name is a file, as before. */
void chimera_roms_install(void);

#endif
