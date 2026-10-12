/* cinterface.c - Fuse behind Chimera's guest interface.
 *
 * Fuse is a desktop program: a main() that reads a command line and a
 * settings file, opens a window and runs until told to stop. Here it is
 * switched on by one call (fuse_chimera_init, the only patch) with the
 * frontend's settings written as the command line Fuse already
 * understands, and then run one television frame at a time. Its window is
 * the "null" one with a display that keeps the picture (chimera_ui.c), its
 * sound card keeps the sound (chimera_sound.c), and its platform layer
 * knows no home folder, no clock and no network (chimera_compat.c).
 *
 * This file compiles IDENTICALLY for the guest (miniBox's emulibc) and for the
 * native reference build (native-shim/emulibc.h): the tests compare the two.
 */
#include "config.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <emulibc.h>
#include <waterbox_settings.h>
#include <waterbox_slots.h>

#include "event.h"
#include "fuse.h"
#include "keyboard.h"
#include "machine.h"
#include "memory_pages.h"
#include "peripherals/joystick.h"
#include "settings.h"
#include "snapshot.h"
#include "spectrum.h"
#include "tape.h"
#include "z80/z80.h"

#include "chimera_glue.h"

int fuse_chimera_init(int argc, char **argv);

/* ---- the wire: waterbox.config "input.buttons" order -----------------------
 * The forty keys of a Spectrum's keyboard, row by row as they are printed;
 * then the tape's Play and Stop, and Reset; then two joysticks of four
 * directions and a fire button. */
static const keyboard_key_name kKeys[] = {
	KEYBOARD_1, KEYBOARD_2, KEYBOARD_3, KEYBOARD_4, KEYBOARD_5, KEYBOARD_6, KEYBOARD_7, KEYBOARD_8, KEYBOARD_9, KEYBOARD_0,
	KEYBOARD_q, KEYBOARD_w, KEYBOARD_e, KEYBOARD_r, KEYBOARD_t, KEYBOARD_y, KEYBOARD_u, KEYBOARD_i, KEYBOARD_o, KEYBOARD_p,
	KEYBOARD_a, KEYBOARD_s, KEYBOARD_d, KEYBOARD_f, KEYBOARD_g, KEYBOARD_h, KEYBOARD_j, KEYBOARD_k, KEYBOARD_l, KEYBOARD_Enter,
	KEYBOARD_Caps, KEYBOARD_z, KEYBOARD_x, KEYBOARD_c, KEYBOARD_v, KEYBOARD_b, KEYBOARD_n, KEYBOARD_m, KEYBOARD_Symbol, KEYBOARD_space,
};
enum {
	KEY_COUNT = 40,
	BTN_TAPE_PLAY = KEY_COUNT,
	BTN_TAPE_STOP,
	BTN_RESET,
	BTN_JOY1, /* Up, Down, Left, Right, Fire */
	BTN_JOY2 = BTN_JOY1 + 5,
	BTN_COUNT = BTN_JOY2 + 5,
};
static const joystick_button kJoy[5] = {
	JOYSTICK_BUTTON_UP, JOYSTICK_BUTTON_DOWN, JOYSTICK_BUTTON_LEFT, JOYSTICK_BUTTON_RIGHT, JOYSTICK_BUTTON_FIRE,
};

static char g_loadError[640];
static int g_inited;
static int g_inputRead;
static uint8_t g_setButtons[BTN_COUNT];
static uint8_t g_held[BTN_COUNT];
static uint64_t g_frames;
static int g_vsyncNum = 50, g_vsyncDen = 1;

/* Fuse reads the keyboard through this one function; the build wraps it
 * (-Wl,--wrap) so that a frame in which the program looked at the keys is
 * known from one in which it did not. */
libspectrum_byte __real_keyboard_read(libspectrum_byte porth);
libspectrum_byte __wrap_keyboard_read(libspectrum_byte porth)
{
	g_inputRead = 1;
	return __real_keyboard_read(porth);
}

/* Fuse uses the C library's rand() in two places (a disc drive's speed and
 * a microdrive cartridge's length) and seeds it from the clock. The C
 * library's generator is another one in another C library, and the clock is
 * nobody's business: the build names these two instead. */
static uint32_t g_rand = 1;
int chimera_rand(void)
{
	g_rand = g_rand * 1103515245u + 12345u;
	return (int)((g_rand >> 16) & 0x7fff);
}
void chimera_srand(unsigned seed) { (void)seed; }

/* A setting's value from the settings the frontend mounted, or the default. */
static const char *setting(const char *name, const char *fallback, char *out, int size)
{
	snprintf(out, size, "%s", fallback);
	wbx_setting_str(name, out, size);
	return out;
}
static int on(const char *name, int fallback)
{
	char v[16];
	setting(name, fallback ? "true" : "false", v, sizeof v);
	return !strcmp(v, "true") || !strcmp(v, "1");
}
static int one_of(const char *value, const char *const *list)
{
	for (int i = 0; list[i]; i++)
		if (!strcmp(value, list[i])) return i;
	return -1;
}

/* the machines, by Fuse's own names for them (machine.c) */
static const char *const kMachines[] = {
	"16", "48", "48_ntsc", "128", "plus2", "plus2a", "plus3", "plus3e", "se", "2048", "2068", "ts2068",
	"pentagon", "pentagon512", "pentagon1024", "scorpion", NULL,
};
/* a joystick socket's kinds, in the order of Fuse's joystick_type_t */
static const char *const kJoysticks[] = {
	"none", "cursor", "kempston", "sinclair1", "sinclair2", "timex1", "timex2", "fuller", NULL,
};

ECL_EXPORT const char *GetLoadError(void) { return g_loadError; }

ECL_EXPORT int Init(void)
{
	g_loadError[0] = '\0';

	/* The program: the project slot's file, else the file the frontend
	 * opened on its own, whose name it mounts beside it. Fuse tells what a
	 * file is (a tape, a snapshot, a disc) from its contents and its name. */
	static char file[512];
	char name[512] = "";
	file[0] = '\0';
	if (wbx_slot_count("media") > 0 && wbx_slot_name("media", 0, name, sizeof name) != NULL) {
		snprintf(file, sizeof file, "%s", name);
	} else {
		FILE *f = fopen("rom.name", "rb");
		if (f) {
			size_t n = fread(file, 1, sizeof file - 1, f);
			fclose(f);
			file[n] = '\0';
			while (n > 0 && (file[n - 1] == '\n' || file[n - 1] == '\r')) file[--n] = '\0';
		}
	}

	static char machine[32], joy1[16], joy2[16], joyArg1[8], joyArg2[8], loading[16];
	setting("machine", "48", machine, sizeof machine);
	if (one_of(machine, kMachines) < 0) {
		snprintf(g_loadError, sizeof g_loadError, "no such machine: %s", machine);
		return 0;
	}
	const int j1 = one_of(setting("joystick_1", "kempston", joy1, sizeof joy1), kJoysticks);
	const int j2 = one_of(setting("joystick_2", "none", joy2, sizeof joy2), kJoysticks);
	if (j1 < 0 || j2 < 0) {
		snprintf(g_loadError, sizeof g_loadError, "no such joystick: %s", j1 < 0 ? joy1 : joy2);
		return 0;
	}
	snprintf(joyArg1, sizeof joyArg1, "%d", j1);
	snprintf(joyArg2, sizeof joyArg2, "%d", j2);
	setting("tape_loading", "fast", loading, sizeof loading);
	if (strcmp(loading, "fast") && strcmp(loading, "real")) {
		snprintf(g_loadError, sizeof g_loadError, "no such way of loading a tape: %s", loading);
		return 0;
	}
	const int fast = !strcmp(loading, "fast");

	/* The settings, as Fuse's command line. What is not said here is Fuse's
	 * own default. Said because a core must:
	 *  --no-fastload         Fuse's "fastload" is not a faster tape, it is
	 *                        the emulator running flat out with the sound
	 *                        off while a tape plays: pacing is the
	 *                        frontend's, and the sound stays on;
	 *  --no-confirm-actions, --no-statusbar, --no-autosave-settings
	 *                        nobody is there to answer, to look, or to have
	 *                        a settings file written for. */
	static char *argv[40];
	int argc = 0;
	argv[argc++] = (char *)"fuse";
	argv[argc++] = (char *)"--machine";
	argv[argc++] = machine;
	argv[argc++] = (char *)"--joystick-1-output";
	argv[argc++] = joyArg1;
	argv[argc++] = (char *)"--joystick-2-output";
	argv[argc++] = joyArg2;
	/* A Kempston joystick needs its interface plugged in, and a Fuller one
	 * the Fuller box: in Fuse those are switches of their own. The Sinclair
	 * sockets are the Interface 2's, which Fuse has plugged in by itself. */
	const int kempston = j1 == 2 || j2 == 2, fuller = j1 == 7 || j2 == 7;
	argv[argc++] = (char *)(kempston ? "--kempston" : "--no-kempston");
	argv[argc++] = (char *)(fuller ? "--fuller" : "--no-fuller");
	/* a tape's fast ways in: the ROM's loading routine answered at once
	 * (traps), and a game's own loader run without waiting for the tape
	 * (accelerate). "real" plays the tape as a tape recorder would. */
	argv[argc++] = (char *)(fast ? "--traps" : "--no-traps");
	argv[argc++] = (char *)(fast ? "--accelerate-loader" : "--no-accelerate-loader");
	argv[argc++] = (char *)(on("auto_load", 1) ? "--auto-load" : "--no-auto-load");
	/* Fuse watches for a program reading the tape and starts the tape for
	 * it, and stops it when the reading ends. With that off the tape is the
	 * buttons Tape Play and Tape Stop's alone. */
	argv[argc++] = (char *)(on("tape_auto", 1) ? "--detect-loader" : "--no-detect-loader");
	argv[argc++] = (char *)(on("issue2", 0) ? "--issue2" : "--no-issue2");
	argv[argc++] = (char *)(on("late_timings", 0) ? "--late-timings" : "--no-late-timings");
	argv[argc++] = (char *)"--no-fastload";
	argv[argc++] = (char *)"--no-confirm-actions";
	argv[argc++] = (char *)"--no-statusbar";
	argv[argc++] = (char *)"--no-autosave-settings";
	if (file[0]) argv[argc++] = file;
	argv[argc] = NULL;

	chimera_last_error[0] = '\0';
	if (fuse_chimera_init(argc, argv)) {
		snprintf(g_loadError, sizeof g_loadError, "Fuse did not start: %s",
			chimera_last_error[0] ? chimera_last_error : "it gave no reason");
		return 0;
	}
	if (chimera_last_error[0] && file[0]) {
		/* Fuse starts the machine even when the file could not be used */
		snprintf(g_loadError, sizeof g_loadError, "%s", chimera_last_error);
		return 0;
	}

	/* the frame rate is the machine's: its processor's speed over the
	 * T-states of one television frame (50.08 for a 48K Spectrum) */
	g_vsyncNum = machine_current->timings.processor_speed;
	g_vsyncDen = machine_current->timings.tstates_per_frame;
	g_inited = 1;
	return 1;
}

ECL_EXPORT void SetButton(int32_t index, int32_t state)
{
	if (index >= 0 && index < BTN_COUNT) g_setButtons[index] = state ? 1 : 0;
}

ECL_EXPORT void SetAxis(int32_t index, int32_t value) { (void)index; (void)value; }

ECL_EXPORT void FrameAdvance(uint64_t packed)
{
	uint8_t now[BTN_COUNT];
	for (int i = 0; i < BTN_COUNT; i++)
		now[i] = g_setButtons[i] | (uint8_t)((packed >> i) & 1);

	if (now[BTN_RESET] && !g_held[BTN_RESET]) machine_reset(0);
	if (now[BTN_TAPE_PLAY] && !g_held[BTN_TAPE_PLAY]) tape_do_play(0);
	if (now[BTN_TAPE_STOP] && !g_held[BTN_TAPE_STOP]) tape_stop();
	for (int i = 0; i < KEY_COUNT; i++) {
		if (now[i] == g_held[i]) continue;
		if (now[i]) keyboard_press(kKeys[i]);
		else keyboard_release(kKeys[i]);
	}
	for (int j = 0; j < 2; j++) {
		for (int b = 0; b < 5; b++) {
			const int i = (j ? BTN_JOY2 : BTN_JOY1) + b;
			if (now[i] != g_held[i]) joystick_press(j, kJoy[b], now[i]);
		}
	}
	memcpy(g_held, now, sizeof g_held);

	g_inputRead = 0;
	chimera_audio_pairs = 0;
	chimera_frame_done = 0;
	/* Fuse's own loop (fuse.c main), until its display says a frame is done */
	while (!chimera_frame_done && !fuse_exiting) {
		z80_do_opcodes();
		event_do_events();
	}
	g_frames++;
	chimera_machine_seconds = (double)g_frames * g_vsyncDen / g_vsyncNum;
}

ECL_EXPORT uint32_t *GetVideoBgra(void) { return chimera_video; }
ECL_EXPORT int GetVideoWidth(void) { return chimera_video_w; }
ECL_EXPORT int GetVideoHeight(void) { return chimera_video_h; }

ECL_EXPORT int16_t *GetAudio(void) { return chimera_audio; }
ECL_EXPORT int GetAudioSampleCount(void) { return chimera_audio_pairs; }

ECL_EXPORT int GetVsyncNumerator(void) { return g_vsyncNum; }
ECL_EXPORT int GetVsyncDenominator(void) { return g_vsyncDen; }

ECL_EXPORT int InputWasRead(void) { return g_inputRead; }

/* The machine's memory for RAM tools: every page of RAM Fuse keeps, 16 KiB
 * each, in the order of the page numbers. A 48K Spectrum uses pages 5, 2
 * and 0 (the screen is at the start of page 5); a 128K one uses 0 to 7; the
 * big Pentagon and Scorpion machines use more. Pages a machine does not have
 * stay as they were when it was switched on. */
ECL_EXPORT int GetMemoryDomainCount(void) { return g_inited ? 1 : 0; }
ECL_EXPORT const char *GetMemoryDomainName(int i) { return i == 0 ? "RAM" : ""; }
ECL_EXPORT uint8_t *GetMemoryDomainPtr(int i) { return i == 0 ? &RAM[0][0] : NULL; }
ECL_EXPORT int64_t GetMemoryDomainSize(int i)
{
	return i == 0 && g_inited ? (int64_t)sizeof RAM : 0;
}
ECL_EXPORT int GetMemoryDomainWritable(int i) { return i == 0 ? 1 : 0; }

/* The machine's memory as its processor sees it: 64 KiB, ROM at the bottom,
 * with whichever pages are switched in. This is the map a game's own
 * addresses are in (the screen at 4000, the system variables at 5C00), and
 * what a RAM tool usually wants. A write to ROM changes nothing. */
ECL_EXPORT int32_t GetBusCount(void) { return g_inited ? 1 : 0; }
ECL_EXPORT const char *GetBusName(int32_t i) { return i == 0 ? "System Bus" : ""; }
ECL_EXPORT int64_t GetBusSize(int32_t i) { return i == 0 ? 0x10000 : 0; }
ECL_EXPORT int32_t GetBusWritable(int32_t i) { return i == 0 ? 1 : 0; }
ECL_EXPORT int32_t PeekBus(int32_t bus, int32_t addr)
{
	if (bus != 0 || !g_inited) return 0;
	return readbyte_internal((libspectrum_word)addr);
}
ECL_EXPORT void PokeBus(int32_t bus, int32_t addr, int32_t value)
{
	if (bus != 0 || !g_inited) return;
	writebyte_internal((libspectrum_word)addr, (libspectrum_byte)value);
}
ECL_EXPORT const uint8_t *ReadBus(int32_t bus, int64_t addr, int32_t len)
{
	/* an answer to a tool is in no savestate */
	ECL_INVISIBLE static uint8_t buffer[0x10000];
	if (bus != 0 || !g_inited || len < 0 || len > (int32_t)sizeof buffer) return NULL;
	for (int32_t i = 0; i < len; i++)
		buffer[i] = readbyte_internal((libspectrum_word)(addr + i));
	return buffer;
}

/* For the tests: Fuse's own unit tests, run on the machine as it stands
 * (they switch through every machine, so they need every ROM, and they
 * write scratch files: the native runner's business). The number that
 * failed. */
int unittests_run(void);
ECL_EXPORT int DebugRunUnitTests(void) { return g_inited ? unittests_run() : -1; }

/* For the tests: the machine as it stands, written as a snapshot file by
 * Fuse (the format is the file name's extension). Native runner only. */
ECL_EXPORT int DebugWriteSnapshot(const char *path) { return g_inited ? snapshot_write(path) : -1; }

/* For the tests: how far the machine has run, and what it is. */
ECL_EXPORT uint64_t GetFrameCount(void) { return g_frames; }
ECL_EXPORT uint32_t GetTstates(void) { return tstates; }
ECL_EXPORT const char *DebugMachine(void)
{
	/* an answer to a tool is in no savestate */
	ECL_INVISIBLE static char text[64];
	snprintf(text, sizeof text, "%s", g_inited ? machine_current->id : "");
	return text;
}
ECL_EXPORT int DebugTapePlaying(void) { return g_inited ? tape_is_playing() : 0; }
