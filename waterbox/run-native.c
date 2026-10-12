#define _GNU_SOURCE
/* The native reference of the core: the same exports the sandbox has
 * (cinterface.cpp, compiled for the host), called directly, a frame at a
 * time, by the same harness the sandboxed runner uses (gate-harness.h).
 *
 *   run-native <program, or - for none> <work directory, which must not exist> [options]
 *
 * The options are the harness's. Natively there are no states. With no
 * program the machine starts as it does when switched on: in its BASIC.
 */
#include <dirent.h>
#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>

#include "gate-harness.h"

int Init(void);
const char *GetLoadError(void);
void FrameAdvance(uint64_t);
int InputWasRead(void);
int16_t *GetAudio(void);
int GetAudioSampleCount(void);
uint32_t *GetVideoBgra(void);
int GetVideoWidth(void);
int GetVideoHeight(void);
int GetVsyncNumerator(void);
int GetVsyncDenominator(void);
uint8_t *GetMemoryDomainPtr(int);
int64_t GetMemoryDomainSize(int);
const char *DebugMachine(void);
uint32_t GetTstates(void);
int DebugTapePlaying(void);
int DebugRunUnitTests(void);
int DebugWriteSnapshot(const char *);

static int write_file(const char *name, const char *text)
{
	FILE *f = fopen(name, "wb");
	if (!f)
		return 0;
	fputs(text, f);
	return fclose(f) == 0;
}

static int copy_file(const char *from, const char *to)
{
	FILE *in = fopen(from, "rb"), *out = in ? fopen(to, "wb") : NULL;
	if (!out) {
		if (in)
			fclose(in);
		return 0;
	}
	char buf[65536];
	size_t n;
	while ((n = fread(buf, 1, sizeof buf, in)) > 0)
		fwrite(buf, 1, n, out);
	fclose(in);
	return fclose(out) == 0;
}

/* a path given relative to where the runner was started still names the
 * same file after the runner has moved into its work directory */
static const char *absolute(const char *path, char *out)
{
	if (!path)
		return NULL;
	if (path[0] == '/')
		return path;
	char cwd[PATH_MAX];
	if (!getcwd(cwd, sizeof cwd))
		return path;
	snprintf(out, PATH_MAX, "%s/%s", cwd, path);
	return out;
}

int main(int argc, char **argv)
{
	if (argc < 3) {
		fprintf(stderr, "usage: run-native <program> <work directory> [options]\n");
		return 2;
	}
	struct harness_opts o;
	if (!harness_parse(argc, argv, 3, &o))
		return 2;
	static char program[PATH_MAX], ppm[PATH_MAX], ram[PATH_MAX], roms[PATH_MAX], snap[PATH_MAX], fixtures[PATH_MAX];
	const int none = !strcmp(argv[1], "-");
	if (!none && !realpath(argv[1], program)) {
		fprintf(stderr, "run-native: no such program: %s\n", argv[1]);
		return 2;
	}
	if (o.roms && !realpath(o.roms, roms)) {
		fprintf(stderr, "run-native: no such folder of ROMs: %s\n", o.roms);
		return 2;
	}
	if (o.fixtures && !realpath(o.fixtures, fixtures)) {
		fprintf(stderr, "run-native: no such folder of fixtures: %s\n", o.fixtures);
		return 2;
	}
	o.ppm = absolute(o.ppm, ppm);
	o.dump_ram = absolute(o.dump_ram, ram);
	o.write_snapshot = absolute(o.write_snapshot, snap);
	/* The core opens "rom.name", "settings", the program and the ROMs where
	 * it is started, as it finds them mounted in the sandbox: the directory
	 * is this run's own, and each file is copied into it under its bare
	 * name. */
	if (mkdir(argv[2], 0777) != 0 || chdir(argv[2]) != 0) {
		fprintf(stderr, "run-native: %s must be a directory that can be made and is not there yet\n", argv[2]);
		return 2;
	}
	const char *base = strrchr(program, '/');
	base = base ? base + 1 : program;
	if (!none && !copy_file(program, base)) {
		fprintf(stderr, "run-native: cannot copy %s into %s\n", program, argv[2]);
		return 2;
	}
	if (o.roms) {
		DIR *d = opendir(roms);
		struct dirent *e;
		while (d && (e = readdir(d)) != NULL) {
			const size_t n = strlen(e->d_name);
			char from[PATH_MAX * 2];
			if (n < 5 || strcmp(e->d_name + n - 4, ".rom"))
				continue;
			snprintf(from, sizeof from, "%s/%s", roms, e->d_name);
			copy_file(from, e->d_name);
		}
		if (d)
			closedir(d);
	}
	/* Fuse's unit tests read their files as lib/tests/<name> */
	if (o.fixtures) {
		DIR *d = opendir(fixtures);
		struct dirent *e;
		mkdir("lib", 0777);
		mkdir("lib/tests", 0777);
		while (d && (e = readdir(d)) != NULL) {
			char from[PATH_MAX * 2], to[PATH_MAX];
			if (e->d_name[0] == '.')
				continue;
			snprintf(from, sizeof from, "%s/%s", fixtures, e->d_name);
			snprintf(to, sizeof to, "lib/tests/%s", e->d_name);
			copy_file(from, to);
		}
		if (d)
			closedir(d);
	}
	if (!write_file("settings", o.settings_json) || (!none && !write_file("rom.name", base))) {
		fprintf(stderr, "run-native: cannot write into %s\n", argv[2]);
		return 2;
	}
	const struct harness_core core = {
		Init, GetLoadError, FrameAdvance, InputWasRead, GetAudio, GetAudioSampleCount, GetVideoBgra, GetVideoWidth,
		GetVideoHeight, GetVsyncNumerator, GetMemoryDomainPtr, GetMemoryDomainSize, GetVsyncDenominator, DebugMachine,
		GetTstates, DebugTapePlaying, DebugRunUnitTests, DebugWriteSnapshot, NULL, NULL, NULL,
	};
	const int result = harness_run(&core, &o);
	fflush(stdout);
	fflush(stderr);
	return result;
}
