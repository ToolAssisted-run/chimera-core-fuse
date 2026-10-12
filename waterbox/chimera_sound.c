/* The sound driver: Fuse mixes a frame's sound and hands it to "the sound
 * card"; this one keeps it for the frontend to take when the frame ends.
 * Fuse's own drivers are in sound/ (alsasound.c and the rest). */
#include "config.h"

#include <string.h>

#include "sound.h"
#include "chimera_glue.h"

int16_t chimera_audio[CHIMERA_AUDIO_MAX_PAIRS * 2];
int chimera_audio_pairs;
static int stereo;

int sound_lowlevel_init(const char *device, int *freqptr, int *stereoptr)
{
	(void)device;
	/* the rate is the package's to say (waterbox.config "audio.rate") */
	*freqptr = CHIMERA_AUDIO_RATE;
	stereo = *stereoptr;
	return 0;
}

void sound_lowlevel_end(void) {}

/* len is in samples: one a moment for a mono machine, two for stereo */
void sound_lowlevel_frame(libspectrum_signed_word *data, int len)
{
	const int pairs = stereo ? len / 2 : len;
	for (int i = 0; i < pairs && chimera_audio_pairs < CHIMERA_AUDIO_MAX_PAIRS; i++) {
		const int16_t l = stereo ? data[2 * i] : data[i];
		const int16_t r = stereo ? data[2 * i + 1] : data[i];
		chimera_audio[2 * chimera_audio_pairs] = l;
		chimera_audio[2 * chimera_audio_pairs + 1] = r;
		chimera_audio_pairs++;
	}
}
