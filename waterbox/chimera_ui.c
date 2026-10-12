/* The display, and what Fuse says when something goes wrong.
 *
 * Fuse has a "null" user interface (ui/null/null_ui.c) in which every
 * function does nothing, and the core is built with it. That file's display
 * functions and its error function are compiled under other names (the
 * build renames them), and these take their place: the picture is kept, and
 * an error is remembered so that the frontend can show it. */
#include "config.h"

#include <stdio.h>
#include <string.h>

#include "display.h"
#include "machine.h"
#include "ui/ui.h"
#include "ui/uidisplay.h"
#include "chimera_glue.h"

uint32_t chimera_video[CHIMERA_VIDEO_MAX_W * CHIMERA_VIDEO_MAX_H];
int chimera_video_w = DISPLAY_ASPECT_WIDTH, chimera_video_h = DISPLAY_SCREEN_HEIGHT;
int chimera_frame_done;
char chimera_last_error[512];

/* A Spectrum's sixteen colours as Fuse's own interfaces show them: the
 * eight colours at 192 of 255, and again at full strength for BRIGHT.
 * Blue is the lowest byte, as the frontend wants a pixel. */
static const uint32_t colours[16] = {
	0xFF000000, 0xFF0000C0, 0xFFC00000, 0xFFC000C0, 0xFF00C000, 0xFF00C0C0, 0xFFC0C000, 0xFFC0C0C0,
	0xFF000000, 0xFF0000FF, 0xFFFF0000, 0xFFFF00FF, 0xFF00FF00, 0xFF00FFFF, 0xFFFFFF00, 0xFFFFFFFF,
};

static int timex;

int uidisplay_init(int width, int height)
{
	(void)width; (void)height;
	timex = machine_current->timex;
	chimera_video_w = timex ? 2 * DISPLAY_ASPECT_WIDTH : DISPLAY_ASPECT_WIDTH;
	chimera_video_h = timex ? 2 * DISPLAY_SCREEN_HEIGHT : DISPLAY_SCREEN_HEIGHT;
	for (int i = 0; i < CHIMERA_VIDEO_MAX_W * CHIMERA_VIDEO_MAX_H; i++)
		chimera_video[i] = 0xFF000000;
	display_ui_initialised = 1;
	return 0;
}

int uidisplay_end(void)
{
	display_ui_initialised = 0;
	return 0;
}

/* A change of machine may be a change of picture size: Fuse calls this. */
int uidisplay_hotswap_gfx_mode(void)
{
	return uidisplay_init(0, 0);
}

void uidisplay_area(int x, int y, int w, int h) { (void)x; (void)y; (void)w; (void)h; }

void uidisplay_frame_end(void) { chimera_frame_done = 1; }

static inline uint32_t *at(int x, int y) { return chimera_video + y * chimera_video_w + x; }

void uidisplay_putpixel(int x, int y, int colour)
{
	const uint32_t c = colours[colour & 15];
	if (timex) {
		uint32_t *p = at(2 * x, 2 * y), *q = at(2 * x, 2 * y + 1);
		p[0] = p[1] = q[0] = q[1] = c;
	} else {
		*at(x, y) = c;
	}
}

/* eight dots at (8*x, y), ink where a bit is set and paper where not */
void uidisplay_plot8(int x, int y, libspectrum_byte data, libspectrum_byte ink, libspectrum_byte paper)
{
	const uint32_t i = colours[ink & 15], p = colours[paper & 15];
	if (timex) {
		for (int row = 0; row < 2; row++) {
			uint32_t *d = at(16 * x, 2 * y + row);
			for (int bit = 0; bit < 8; bit++)
				d[2 * bit] = d[2 * bit + 1] = (data & (0x80 >> bit)) ? i : p;
		}
	} else {
		uint32_t *d = at(8 * x, y);
		for (int bit = 0; bit < 8; bit++)
			d[bit] = (data & (0x80 >> bit)) ? i : p;
	}
}

/* sixteen dots at (16*x, y) of the doubled picture: the Timex's wide mode */
void uidisplay_plot16(int x, int y, libspectrum_word data, libspectrum_byte ink, libspectrum_byte paper)
{
	const uint32_t i = colours[ink & 15], p = colours[paper & 15];
	for (int row = 0; row < 2; row++) {
		uint32_t *d = at(16 * x, 2 * y + row);
		for (int bit = 0; bit < 16; bit++)
			d[bit] = (data & (0x8000 >> bit)) ? i : p;
	}
}

int ui_error_specific(ui_error_level severity, const char *message)
{
	/* the last thing said is the nearest to what stopped the machine */
	if (severity >= UI_ERROR_ERROR || !chimera_last_error[0])
		snprintf(chimera_last_error, sizeof chimera_last_error, "%s", message);
	return 0;
}
